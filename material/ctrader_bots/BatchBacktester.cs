/*
 * ══════════════════════════════════════════════════════════════════════════
 *  BatchBacktester — cTrader Plugin for Headless Batch Backtesting
 * ══════════════════════════════════════════════════════════════════════════
 *
 *  API reference: official cTrader "BacktestingInPlugins Sample"
 *  https://github.com/spotware/ctrader-algo-samples
 *
 *  Usage:
 *    1. Load & compile all cBots in cTrader Automate
 *    2. Load this plugin (Automate → Plugins → New Plugin → paste → Build)
 *    3. Click "▶ Start Batch" in the ASP panel
 *    4. Results export to Desktop\BACKTEST\results\backtest_results.csv
 * ══════════════════════════════════════════════════════════════════════════
 */

using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Nodes;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Plugins
{
    [Plugin(AccessRights = AccessRights.FullAccess)]
    public class BatchBacktester : Plugin
    {
        // ═══════════════════════════════════════════════
        //  CONFIGURATION — Edit these to match your setup
        // ═══════════════════════════════════════════════

        // Bot names MUST match exactly what you named them in cTrader Automate.
        // The plugin will skip any names it can't find in AlgoRegistry.
        private readonly string[] _botNames = new[]
        {
            "SMP1_Base",
            "SMP1_Updated",
            "FibEMA_Kelly",
            "FibEMA_RiskMode",
            "FibEMA_Hedge",
            "FibEMA_ModPos",
            "FibRegime6",
            "FibRegime7",
        };

        // Symbols to test
        private readonly string[] _symbols = new[]
        {
            "XAUUSD",
        };

        // Timeframes to test
        private readonly TimeFrame[] _timeframes = new[]
        {
            TimeFrame.Minute5,
            TimeFrame.Minute10,
            TimeFrame.Minute15,
            TimeFrame.Minute30,
            TimeFrame.Hour,
        };

        // Backtest date range
        private readonly DateTime _startDate = new DateTime(2020, 1, 1);
        private readonly DateTime _endDate = DateTime.UtcNow;

        // Account settings
        private readonly double _balance = 10000;

        // Output path
        private readonly string _outputDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
            "BACKTEST", "results"
        );

        // ═══════════════════════════════════════════════
        //  STATE
        // ═══════════════════════════════════════════════

        private Queue<BacktestJob> _queue;
        private List<BacktestResult> _results;
        private BacktestJob _currentJob;
        private int _totalJobs;
        private int _completedJobs;
        private bool _isRunning;
        private Button _startButton;
        private TextBlock _statusText;

        // ═══════════════════════════════════════════════
        //  DATA STRUCTURES
        // ═══════════════════════════════════════════════

        private class BacktestJob
        {
            public string BotName;
            public RobotType RobotType;
            public string Symbol;
            public TimeFrame TimeFrame;
        }

        private class BacktestResult
        {
            public string BotName;
            public string Symbol;
            public string TimeFrame;
            public double NetProfit;
            public double ROI;
            public double ProfitFactor;
            public double WinRate;
            public double MaxEquityDDPercent;
            public double MaxBalanceDDPercent;
            public int TotalTrades;
            public int WinningTrades;
            public int LosingTrades;
            public double SharpeRatio;
            public double Expectancy;
            public double GrossProfit;
            public double GrossLoss;
            public double Commissions;
            public string Status; // "OK", "ERROR", "NOT_FOUND", "NO_TRADES"
            public string ErrorMsg;
            public double CompositeScore;
        }

        // ═══════════════════════════════════════════════
        //  PLUGIN LIFECYCLE
        // ═══════════════════════════════════════════════

        protected override void OnStart()
        {
            // Subscribe to backtesting events
            Backtesting.Completed += OnBacktestCompleted;

            // Build UI in Active Symbol Panel
            var grid = new Grid(3, 1);

            _startButton = new Button
            {
                BackgroundColor = Color.FromHex("#2196F3"),
                CornerRadius = new CornerRadius(5),
                Text = "▶ Start Batch Backtest",
                Margin = 5,
            };
            _startButton.Click += OnStartClicked;

            _statusText = new TextBlock
            {
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Text = "Ready. Click Start to begin.",
                Margin = 5,
            };

            grid.AddChild(_startButton, 0, 0);
            grid.AddChild(_statusText, 1, 0);

            var block = Asp.SymbolTab.AddBlock("Batch Backtester");
            block.Child = grid;

            _results = new List<BacktestResult>();
            _isRunning = false;

            // Count available bots
            int found = 0;
            foreach (var name in _botNames)
            {
                var robot = AlgoRegistry.Get(name) as RobotType;
                if (robot != null) found++;
            }
            _statusText.Text = $"Found {found}/{_botNames.Length} bots. {found * _symbols.Length * _timeframes.Length} combos ready.";
        }

        protected override void OnStop()
        {
            Backtesting.Completed -= OnBacktestCompleted;
        }

        // ═══════════════════════════════════════════════
        //  BATCH CONTROL
        // ═══════════════════════════════════════════════

        private void OnStartClicked(ButtonClickEventArgs args)
        {
            if (_isRunning)
            {
                Print("⚠ Batch already running.");
                return;
            }

            _isRunning = true;
            _results.Clear();
            _startButton.IsEnabled = false;
            _startButton.Text = "⏳ Running...";

            // Build the job queue, resolving RobotTypes from AlgoRegistry
            _queue = new Queue<BacktestJob>();
            foreach (var botName in _botNames)
            {
                var robotType = AlgoRegistry.Get(botName) as RobotType;
                if (robotType == null)
                {
                    Print($"⚠ Bot '{botName}' not found in AlgoRegistry. Skipping.");
                    _results.Add(new BacktestResult
                    {
                        BotName = botName,
                        Symbol = "—",
                        TimeFrame = "—",
                        Status = "NOT_FOUND",
                        ErrorMsg = "Not found in AlgoRegistry. Check the name matches exactly.",
                    });
                    continue;
                }

                foreach (var sym in _symbols)
                {
                    foreach (var tf in _timeframes)
                    {
                        _queue.Enqueue(new BacktestJob
                        {
                            BotName = botName,
                            RobotType = robotType,
                            Symbol = sym,
                            TimeFrame = tf,
                        });
                    }
                }
            }

            _totalJobs = _queue.Count;
            _completedJobs = 0;

            Print("═══════════════════════════════════════════════");
            Print("  BATCH BACKTEST STARTED");
            Print($"  {_totalJobs} jobs queued");
            Print($"  Period: {_startDate:yyyy-MM-dd} → {_endDate:yyyy-MM-dd}");
            Print($"  Balance: ${_balance:N0}");
            Print("═══════════════════════════════════════════════");

            RunNext();
        }

        private void RunNext()
        {
            if (_queue.Count == 0)
            {
                OnBatchComplete();
                return;
            }

            _currentJob = _queue.Dequeue();
            _completedJobs++;

            var progress = $"[{_completedJobs}/{_totalJobs}]";
            var label = $"{_currentJob.BotName} / {_currentJob.Symbol} / {_currentJob.TimeFrame}";
            _statusText.Text = $"{progress} {label}";
            Print($"\n🤖 {progress} {label}");

            try
            {
                var settings = new BacktestingSettings
                {
                    DataMode = BacktestingDataMode.M1,
                    StartTimeUtc = _startDate,
                    EndTimeUtc = _endDate,
                    Balance = _balance,
                };

                Backtesting.Start(
                    _currentJob.RobotType,
                    _currentJob.Symbol,
                    _currentJob.TimeFrame,
                    settings);
            }
            catch (Exception ex)
            {
                Print($"  ✗ Failed to start: {ex.Message}");
                _results.Add(new BacktestResult
                {
                    BotName = _currentJob.BotName,
                    Symbol = _currentJob.Symbol,
                    TimeFrame = _currentJob.TimeFrame.ToString(),
                    Status = "ERROR",
                    ErrorMsg = ex.Message,
                });
                RunNext();
            }
        }

        // ═══════════════════════════════════════════════
        //  RESULT EXTRACTION (from JsonReport)
        // ═══════════════════════════════════════════════

        private void OnBacktestCompleted(BacktestingCompletedEventArgs obj)
        {
            var result = new BacktestResult
            {
                BotName = _currentJob.BotName,
                Symbol = _currentJob.Symbol,
                TimeFrame = _currentJob.TimeFrame.ToString(),
            };

            try
            {
                // Parse the JSON report
                string json = obj.JsonReport;
                
                // Dump the first raw JSON so we can analyze the schema
                if (_completedJobs == 1)
                {
                    Directory.CreateDirectory(_outputDir);
                    File.WriteAllText(Path.Combine(_outputDir, "raw_json_debug.json"), json);
                }

                JsonNode root = JsonNode.Parse(json);
                JsonNode main = root["main"];
                JsonNode stats = root["statistics"]; // Add a guess for statistics node

                // Extract metrics from JSON
                result.NetProfit = GetDouble(main, "netProfit");
                result.ROI = GetDouble(main, "roi");
                
                // Try reading trades from 'main', fallback to 'statistics'
                result.TotalTrades = GetInt(main, "totalTrades") > 0 ? GetInt(main, "totalTrades") : GetInt(stats, "totalTrades");
                result.WinningTrades = GetInt(main, "winningTrades") > 0 ? GetInt(main, "winningTrades") : GetInt(stats, "winningTrades");
                result.LosingTrades = GetInt(main, "losingTrades") > 0 ? GetInt(main, "losingTrades") : GetInt(stats, "losingTrades");
                
                result.GrossProfit = GetDouble(main, "grossProfit") != 0 ? GetDouble(main, "grossProfit") : GetDouble(stats, "grossProfit");
                result.GrossLoss = GetDouble(main, "grossLoss") != 0 ? GetDouble(main, "grossLoss") : GetDouble(stats, "grossLoss");
                
                result.MaxEquityDDPercent = GetDouble(main, "maxEquityDrawdownPercentages") != 0 ? GetDouble(main, "maxEquityDrawdownPercentages") : GetDouble(stats, "maxEquityDrawdownPercentages");
                result.MaxBalanceDDPercent = GetDouble(main, "maxBalanceDrawdownPercentages") != 0 ? GetDouble(main, "maxBalanceDrawdownPercentages") : GetDouble(stats, "maxBalanceDrawdownPercentages");
                
                result.SharpeRatio = GetDouble(main, "sharpeRatio") != 0 ? GetDouble(main, "sharpeRatio") : GetDouble(stats, "sharpeRatio");
                result.Commissions = GetDouble(main, "totalCommissions") != 0 ? GetDouble(main, "totalCommissions") : GetDouble(stats, "totalCommissions");

                // Computed metrics
                if (result.TotalTrades > 0)
                {
                    result.WinRate = (double)result.WinningTrades / result.TotalTrades;
                    result.Expectancy = result.NetProfit / result.TotalTrades;
                }

                double absLoss = Math.Abs(result.GrossLoss);
                result.ProfitFactor = absLoss > 0
                    ? result.GrossProfit / absLoss
                    : (result.GrossProfit > 0 ? 999 : 0);

                // Composite score
                result.CompositeScore = ComputeScore(result);
                result.Status = result.TotalTrades > 0 ? "OK" : "NO_TRADES";

                Print($"  ✓ Trades={result.TotalTrades} | PF={result.ProfitFactor:F2} | " +
                      $"WR={result.WinRate:P1} | DD={result.MaxEquityDDPercent:F1}% | " +
                      $"Net=${result.NetProfit:F2} | Score={result.CompositeScore:F4}");
            }
            catch (Exception ex)
            {
                result.Status = "ERROR";
                result.ErrorMsg = $"JSON parse error: {ex.Message}";
                Print($"  ✗ Error: {ex.Message}");

                // Dump raw JSON for debugging
                try { Print($"  Raw JSON (first 500 chars): {obj.JsonReport?.Substring(0, Math.Min(500, obj.JsonReport?.Length ?? 0))}"); }
                catch { }
            }

            _results.Add(result);
            RunNext();
        }

        // JSON helper — safely extract double
        private double GetDouble(JsonNode node, string key)
        {
            try { return node[key]?.GetValue<double>() ?? 0; }
            catch { return 0; }
        }

        // JSON helper — safely extract int
        private int GetInt(JsonNode node, string key)
        {
            try { return node[key]?.GetValue<int>() ?? 0; }
            catch { return 0; }
        }

        // ═══════════════════════════════════════════════
        //  SCORING
        // ═══════════════════════════════════════════════

        private double ComputeScore(BacktestResult r)
        {
            if (r.TotalTrades < 5) return 0;

            // Normalize components to 0–1
            double pfNorm = Math.Min(r.ProfitFactor, 5.0) / 5.0;
            double wrNorm = r.WinRate;
            double ddNorm = Math.Max(0, 1.0 - r.MaxEquityDDPercent / 100.0);

            // Expectancy normalized: $0–$50 per trade → 0–1
            double expNorm = Math.Max(0, Math.Min(r.Expectancy / 50.0, 1.0));

            double score = 0.35 * pfNorm + 0.25 * wrNorm + 0.20 * expNorm + 0.20 * ddNorm;

            // Penalties
            if (r.MaxEquityDDPercent > 25) score -= (r.MaxEquityDDPercent - 25) / 200.0;
            if (r.TotalTrades < 15) score -= 0.05;

            return Math.Max(0, Math.Round(score, 4));
        }

        // ═══════════════════════════════════════════════
        //  BATCH COMPLETE — LEADERBOARD & CSV EXPORT
        // ═══════════════════════════════════════════════

        private void OnBatchComplete()
        {
            _isRunning = false;
            _startButton.IsEnabled = true;
            _startButton.Text = "▶ Start Batch Backtest";

            var ranked = _results
                .Where(r => r.Status == "OK")
                .OrderByDescending(r => r.CompositeScore)
                .ToList();

            // ── Print Leaderboard ──
            Print("\n═══════════════════════════════════════════════");
            Print("  📋 FINAL LEADERBOARD");
            Print("═══════════════════════════════════════════════");
            Print($"{"#",3} {"Bot",-18} {"Sym",-8} {"TF",-7} {"Score",7} {"PF",6} {"WR",6} {"DD%",6} {"Trades",6} {"Net$",10}");
            Print("───────────────────────────────────────────────────────────────────────────");

            for (int i = 0; i < ranked.Count; i++)
            {
                var r = ranked[i];
                Print($"{i + 1,3} {r.BotName,-18} {r.Symbol,-8} {r.TimeFrame,-7} " +
                      $"{r.CompositeScore,7:F4} {r.ProfitFactor,6:F2} {r.WinRate,6:P0} " +
                      $"{r.MaxEquityDDPercent,6:F1} {r.TotalTrades,6} {r.NetProfit,10:F2}");
            }

            // Print failures
            var failures = _results.Where(r => r.Status != "OK").ToList();
            if (failures.Count > 0)
            {
                Print($"\n⚠ {failures.Count} issues:");
                foreach (var f in failures)
                    Print($"  {f.BotName}/{f.Symbol}/{f.TimeFrame}: [{f.Status}] {f.ErrorMsg}");
            }

            Print($"\n  Total: {ranked.Count} ranked, {failures.Count} failed/skipped");

            // ── Export CSV ──
            ExportCsv();

            _statusText.Text = $"✅ Done! {ranked.Count} results. CSV saved.";
        }

        private void ExportCsv()
        {
            try
            {
                Directory.CreateDirectory(_outputDir);
                var path = Path.Combine(_outputDir, $"backtest_results_{DateTime.Now:yyyyMMdd_HHmmss}.csv");

                var sb = new StringBuilder();

                // Header
                sb.AppendLine("Rank,Bot,Symbol,TimeFrame,Score,NetProfit,ROI,ProfitFactor," +
                              "WinRate,MaxEquityDD%,MaxBalanceDD%,TotalTrades,WinningTrades," +
                              "LosingTrades,SharpeRatio,Expectancy,GrossProfit,GrossLoss," +
                              "Commissions,Status,Error");

                var ranked = _results
                    .OrderByDescending(r => r.CompositeScore)
                    .ToList();

                int rank = 0;
                foreach (var r in ranked)
                {
                    rank++;
                    sb.AppendLine(
                        $"{(r.Status == "OK" ? rank.ToString() : "—")}," +
                        $"{Esc(r.BotName)},{Esc(r.Symbol)},{Esc(r.TimeFrame)}," +
                        $"{r.CompositeScore:F4},{r.NetProfit:F2},{r.ROI:F2},{r.ProfitFactor:F2}," +
                        $"{r.WinRate:F4},{r.MaxEquityDDPercent:F2},{r.MaxBalanceDDPercent:F2}," +
                        $"{r.TotalTrades},{r.WinningTrades},{r.LosingTrades}," +
                        $"{r.SharpeRatio:F4},{r.Expectancy:F2}," +
                        $"{r.GrossProfit:F2},{r.GrossLoss:F2},{r.Commissions:F2}," +
                        $"{r.Status},{Esc(r.ErrorMsg ?? "")}");
                }

                File.WriteAllText(path, sb.ToString());
                Print($"\n📄 CSV saved: {path}");
            }
            catch (Exception ex)
            {
                Print($"✗ CSV export failed: {ex.Message}");
            }
        }

        // Escape commas for CSV
        private string Esc(string s) => s?.Contains(",") == true ? $"\"{s}\"" : (s ?? "");
    }
}
