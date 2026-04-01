using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace cAlgo.Robots
{
    /// <summary>
    /// TCP Bridge cBot — Listens on 127.0.0.1:5555 and executes commands
    /// from the Python multi_runner via a simple pipe-delimited protocol.
    ///
    /// All cTrader API calls (Account, Positions, ExecuteMarketOrder, etc.)
    /// are marshalled to the main thread via BeginInvokeOnMainThread to avoid
    /// AutomateDispatcherUnhandledException.
    ///
    /// Protocol (newline-terminated, pipe-delimited):
    ///   GET_BALANCE                              -> BALANCE|{float}
    ///   GET_POSITION|{symbol}                    -> POSITION|{symbol}|{side}|{size}|{avgPrice}|{unrealPnl}
    ///                                               POSITION|NONE
    ///   ORDER|{symbol}|{Buy/Sell}|{qty}|{sl}|{tp}|{label}  -> ORDER_SUCCESS|{orderId}
    ///                                                           ORDER_ERROR|{message}
    ///   CLOSE|{symbol}                           -> CLOSE_SUCCESS|{orderId}
    ///                                               CLOSE_ERROR|{message}
    ///   CANCEL_ALL|{symbol}                      -> CANCEL_SUCCESS
    ///   PING                                     -> PONG
    /// </summary>
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.FullAccess)]
    public class TcpBridgeBot : Robot
    {
        [Parameter("Listen Port", DefaultValue = 5555)]
        public int ListenPort { get; set; }

        [Parameter("Listen Address", DefaultValue = "127.0.0.1")]
        public string ListenAddress { get; set; }

        [Parameter("Trade Label Prefix", DefaultValue = "PY_BRIDGE")]
        public string TradeLabelPrefix { get; set; }

        private TcpListener _listener;
        private Thread _listenThread;
        private volatile bool _running;
        private readonly object _clientLock = new object();
        private TcpClient _currentClient;

        protected override void OnStart()
        {
            _running = true;
            _listenThread = new Thread(ListenLoop)
            {
                IsBackground = true,
                Name = "TcpBridgeListener"
            };
            _listenThread.Start();
            Print($"[TcpBridge] Listening on {ListenAddress}:{ListenPort}");
        }

        protected override void OnStop()
        {
            _running = false;
            try { _listener?.Stop(); } catch { }
            lock (_clientLock)
            {
                try { _currentClient?.Close(); } catch { }
                _currentClient = null;
            }
            Print("[TcpBridge] Stopped.");
        }

        protected override void OnTick()
        {
            // Keep bot alive — no per-tick logic needed
        }

        // ────────────────────────────────────────────────────────────
        //  MAIN-THREAD MARSHALLING
        // ────────────────────────────────────────────────────────────

        /// <summary>
        /// Execute an action on the cTrader main thread and wait for it to complete.
        /// This is required because Account, Positions, ExecuteMarketOrder, etc.
        /// throw AutomateDispatcherUnhandledException when called from background threads.
        /// </summary>
        private T RunOnMainThread<T>(Func<T> func, int timeoutMs = 10000)
        {
            T result = default;
            Exception caught = null;
            var done = new ManualResetEventSlim(false);

            BeginInvokeOnMainThread(() =>
            {
                try
                {
                    result = func();
                }
                catch (Exception ex)
                {
                    caught = ex;
                }
                finally
                {
                    done.Set();
                }
            });

            if (!done.Wait(timeoutMs))
                throw new TimeoutException($"Main-thread call timed out after {timeoutMs}ms");

            if (caught != null)
                throw caught;

            return result;
        }

        // ────────────────────────────────────────────────────────────
        //  TCP LISTENER
        // ────────────────────────────────────────────────────────────

        private void ListenLoop()
        {
            try
            {
                var address = IPAddress.Parse(ListenAddress);
                _listener = new TcpListener(address, ListenPort);
                _listener.Start();

                while (_running)
                {
                    Print("[TcpBridge] Waiting for Python client...");
                    TcpClient client;
                    try
                    {
                        client = _listener.AcceptTcpClient();
                    }
                    catch (SocketException) when (!_running)
                    {
                        break;
                    }

                    lock (_clientLock)
                    {
                        try { _currentClient?.Close(); } catch { }
                        _currentClient = client;
                    }

                    Print($"[TcpBridge] Client connected from {((IPEndPoint)client.Client.RemoteEndPoint).Address}");
                    HandleClient(client);
                    Print("[TcpBridge] Client disconnected.");
                }
            }
            catch (Exception ex)
            {
                if (_running)
                    Print($"[TcpBridge] ListenLoop error: {ex.Message}");
            }
        }

        private void HandleClient(TcpClient client)
        {
            var stream = client.GetStream();
            var buffer = new byte[4096];
            var leftover = "";

            try
            {
                while (_running && client.Connected)
                {
                    int bytesRead;
                    try
                    {
                        bytesRead = stream.Read(buffer, 0, buffer.Length);
                    }
                    catch (Exception)
                    {
                        break;
                    }

                    if (bytesRead == 0) break;

                    leftover += Encoding.UTF8.GetString(buffer, 0, bytesRead);

                    while (leftover.Contains("\n"))
                    {
                        int idx = leftover.IndexOf('\n');
                        string line = leftover.Substring(0, idx).Trim();
                        leftover = leftover.Substring(idx + 1);

                        if (string.IsNullOrEmpty(line)) continue;

                        string response;
                        try
                        {
                            response = ProcessCommand(line);
                        }
                        catch (Exception ex)
                        {
                            response = $"ERROR|{ex.Message}";
                            Print($"[TcpBridge] Command error: {ex.Message}");
                        }

                        byte[] respBytes = Encoding.UTF8.GetBytes(response + "\n");
                        try
                        {
                            stream.Write(respBytes, 0, respBytes.Length);
                            stream.Flush();
                        }
                        catch (Exception)
                        {
                            return;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                if (_running)
                    Print($"[TcpBridge] HandleClient error: {ex.Message}");
            }
            finally
            {
                try { client.Close(); } catch { }
            }
        }

        // ────────────────────────────────────────────────────────────
        //  COMMAND DISPATCH
        // ────────────────────────────────────────────────────────────

        private string ProcessCommand(string line)
        {
            var parts = line.Split('|');
            var cmd = parts[0].ToUpperInvariant();

            switch (cmd)
            {
                case "PING":
                    return "PONG";

                case "GET_BALANCE":
                    return HandleGetBalance();

                case "GET_POSITION":
                    if (parts.Length < 2) return "ERROR|Missing symbol";
                    return HandleGetPosition(parts[1].Trim());

                case "ORDER":
                    if (parts.Length < 6) return "ORDER_ERROR|Missing parameters (need symbol|side|qty|sl|tp)";
                    return HandleOrder(parts);

                case "CLOSE":
                    if (parts.Length < 2) return "CLOSE_ERROR|Missing symbol";
                    return HandleClose(parts[1].Trim());

                case "CANCEL_ALL":
                    if (parts.Length < 2) return "ERROR|Missing symbol";
                    return HandleCancelAll(parts[1].Trim());

                default:
                    return $"ERROR|Unknown command: {cmd}";
            }
        }

        // ────────────────────────────────────────────────────────────
        //  HANDLERS (all cTrader API calls go through RunOnMainThread)
        // ────────────────────────────────────────────────────────────

        private string HandleGetBalance()
        {
            double balance = RunOnMainThread(() => Account.Balance);
            return $"BALANCE|{balance.ToString("F2", CultureInfo.InvariantCulture)}";
        }

        private string HandleGetPosition(string symbol)
        {
            return RunOnMainThread(() =>
            {
                var symbolObj = ResolveSymbol(symbol);
                if (symbolObj == null)
                    return "POSITION|NONE";

                var positions = Positions.FindAll(TradeLabelPrefix, symbolObj.Name);
                if (positions.Length == 0)
                    return "POSITION|NONE";

                double netQty = 0;
                double totalPnl = 0;
                double weightedPrice = 0;
                double totalVolume = 0;

                foreach (var pos in positions)
                {
                    double vol = pos.VolumeInUnits;
                    double sign = pos.TradeType == TradeType.Buy ? 1.0 : -1.0;
                    netQty += sign * vol;
                    totalPnl += pos.NetProfit;
                    weightedPrice += pos.EntryPrice * vol;
                    totalVolume += vol;
                }

                if (totalVolume == 0)
                    return "POSITION|NONE";

                double avgPrice = weightedPrice / totalVolume;
                string side = netQty >= 0 ? "Buy" : "Sell";
                double absSize = Math.Abs(netQty);

                return string.Format(CultureInfo.InvariantCulture,
                    "POSITION|{0}|{1}|{2:F2}|{3:F5}|{4:F2}",
                    symbol, side, absSize, avgPrice, totalPnl);
            });
        }

        private string HandleOrder(string[] parts)
        {
            string symbol = parts[1].Trim();
            string sideStr = parts[2].Trim();
            string qtyStr = parts[3].Trim();
            string slStr = parts[4].Trim();
            string tpStr = parts[5].Trim();
            string label = parts.Length > 6 ? parts[6].Trim() : "";

            TradeType tradeType;
            if (sideStr.Equals("Buy", StringComparison.OrdinalIgnoreCase))
                tradeType = TradeType.Buy;
            else if (sideStr.Equals("Sell", StringComparison.OrdinalIgnoreCase))
                tradeType = TradeType.Sell;
            else
                return $"ORDER_ERROR|Invalid side '{sideStr}' (use Buy or Sell)";

            if (!double.TryParse(qtyStr, NumberStyles.Float, CultureInfo.InvariantCulture, out double lots))
                return $"ORDER_ERROR|Invalid qty '{qtyStr}'";

            double? slPrice = null;
            if (double.TryParse(slStr, NumberStyles.Float, CultureInfo.InvariantCulture, out double slVal) && slVal > 0)
                slPrice = slVal;

            double? tpPrice = null;
            if (double.TryParse(tpStr, NumberStyles.Float, CultureInfo.InvariantCulture, out double tpVal) && tpVal > 0)
                tpPrice = tpVal;

            string fullLabel = string.IsNullOrEmpty(label)
                ? TradeLabelPrefix
                : $"{TradeLabelPrefix}_{label}";

            return RunOnMainThread(() =>
            {
                var symbolObj = ResolveSymbol(symbol);
                if (symbolObj == null)
                    return $"ORDER_ERROR|Symbol '{symbol}' not found in cTrader";

                double volumeInUnits = symbolObj.QuantityToVolumeInUnits(lots);
                if (volumeInUnits < symbolObj.VolumeInUnitsMin)
                    volumeInUnits = symbolObj.VolumeInUnitsMin;

                volumeInUnits = symbolObj.NormalizeVolumeInUnits(volumeInUnits, RoundingMode.ToNearest);

                // Convert absolute SL/TP prices to pips
                double? slPips = null;
                double? tpPips = null;

                double currentPrice = tradeType == TradeType.Buy ? symbolObj.Ask : symbolObj.Bid;

                if (slPrice.HasValue)
                {
                    double slDist = Math.Abs(currentPrice - slPrice.Value);
                    slPips = slDist / symbolObj.PipSize;
                }

                if (tpPrice.HasValue)
                {
                    double tpDist = Math.Abs(currentPrice - tpPrice.Value);
                    tpPips = tpDist / symbolObj.PipSize;
                }

                Print($"[TcpBridge] ORDER: {tradeType} {lots} lots {symbol} | SL={slPips:F1} pips | TP={tpPips:F1} pips | Label={fullLabel}");

                var result = ExecuteMarketOrder(tradeType, symbolObj.Name, volumeInUnits, fullLabel, slPips, tpPips);

                if (result.IsSuccessful)
                {
                    string orderId = result.Position != null
                        ? result.Position.Id.ToString()
                        : "OK";
                    Print($"[TcpBridge] ORDER_SUCCESS: {orderId}");
                    return $"ORDER_SUCCESS|{orderId}";
                }
                else
                {
                    string error = result.Error.ToString();
                    Print($"[TcpBridge] ORDER_ERROR: {error}");
                    return $"ORDER_ERROR|{error}";
                }
            });
        }

        private string HandleClose(string symbol)
        {
            return RunOnMainThread(() =>
            {
                var symbolObj = ResolveSymbol(symbol);
                if (symbolObj == null)
                    return $"CLOSE_ERROR|Symbol '{symbol}' not found";

                var positions = Positions.FindAll(TradeLabelPrefix, symbolObj.Name);
                if (positions.Length == 0)
                    return $"CLOSE_ERROR|No open positions for {symbol}";

                var errors = new List<string>();
                var closedIds = new List<string>();

                foreach (var pos in positions)
                {
                    var result = ClosePosition(pos);
                    if (result.IsSuccessful)
                    {
                        closedIds.Add(pos.Id.ToString());
                    }
                    else
                    {
                        errors.Add($"{pos.Id}:{result.Error}");
                    }
                }

                if (errors.Count > 0)
                {
                    Print($"[TcpBridge] CLOSE partial errors: {string.Join(", ", errors)}");
                    return $"CLOSE_ERROR|Partial: closed={closedIds.Count}, errors={string.Join(";", errors)}";
                }

                string ids = string.Join(",", closedIds);
                Print($"[TcpBridge] CLOSE_SUCCESS: {ids}");
                return $"CLOSE_SUCCESS|{ids}";
            });
        }

        private string HandleCancelAll(string symbol)
        {
            return RunOnMainThread(() =>
            {
                var symbolObj = ResolveSymbol(symbol);
                if (symbolObj == null)
                    return "CANCEL_SUCCESS";

                var orders = PendingOrders.Where(o =>
                    o.SymbolName == symbolObj.Name &&
                    o.Label != null &&
                    o.Label.StartsWith(TradeLabelPrefix)).ToArray();

                foreach (var order in orders)
                {
                    CancelPendingOrder(order);
                }

                Print($"[TcpBridge] CANCEL_ALL: cancelled {orders.Length} pending orders for {symbol}");
                return "CANCEL_SUCCESS";
            });
        }

        // ────────────────────────────────────────────────────────────
        //  HELPERS
        // ────────────────────────────────────────────────────────────

        /// <summary>
        /// Resolve symbol name. Must be called on main thread (inside RunOnMainThread).
        /// </summary>
        private Symbol ResolveSymbol(string name)
        {
            try
            {
                return Symbols.GetSymbol(name);
            }
            catch { }

            string[] suffixes = { "m", ".s", "_SB", "pro" };
            foreach (var suffix in suffixes)
            {
                try
                {
                    var sym = Symbols.GetSymbol(name + suffix);
                    if (sym != null) return sym;
                }
                catch { }
            }

            Print($"[TcpBridge] WARNING: Could not resolve symbol '{name}'");
            return null;
        }
    }
}
