using cAlgo.API;
using cAlgo.API.Indicators;
using System;

namespace cAlgo.Robots
{
    // ════════════════════════════════════════════════════════════════════════
    //  SMP1UpdateCool — SMP1Updated + SWING-BASED COOLDOWN
    //  Python port: backtest/bots/smp1_update_cool.py
    // ════════════════════════════════════════════════════════════════════════
    //
    //  PROBLEM SOLVED
    //  ──────────────
    //  Gold ran ~$4400 → $5300+ in Jan–Feb 2026.  SMP1 detected bearish
    //  pullback bars inside the bull trend and kept entering SELL.  After
    //  each SL hit the bot re-evaluated — the SAME swing was still dominant,
    //  so it entered again off the same leg, stacking consecutive losses.
    //
    //  KEY CHANGES vs SMP1Updated
    //  ───────────────────────────
    //  1. ONE TRADE AT A TIME (hard gate, same as SMP1Updated)
    //  2. SWING-BASED COOLDOWN (NEW — no arbitrary bar count):
    //       After any trade closes, new setups are BLOCKED until
    //       compute_swing_hl() returns a swing high > anchor_high + ATR×mult
    //       OR  a swing low < anchor_low − ATR×mult.
    //       Anchor = the swing high/low AT SETUP ACTIVATION (not at close).
    //  3. MAX SL PIPS = 150 (hard cap on SL distance)
    //
    //  COOLDOWN ATR MULTIPLIER
    //  ───────────────────────
    //  Default: 1.5 × ATR  (recommended range: 1.0 – 3.0)
    //  Higher  = longer cooldown, fewer trades, more structural confirmation.
    //  Lower   = quicker re-entry, still requires some swing extension.
    //
    // ════════════════════════════════════════════════════════════════════════

    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class SMP1UpdateCool : Robot
    {
        // ── Core parameters ──────────────────────────────────────────────────
        [Parameter("EMA Fast",          DefaultValue = 50)]
        public int EmaFast { get; set; }

        [Parameter("EMA Slow",          DefaultValue = 200)]
        public int EmaSlow { get; set; }

        [Parameter("ATR Period",        DefaultValue = 14)]
        public int AtrPeriod { get; set; }

        [Parameter("Swing Lookback",    DefaultValue = 15)]
        public int SwingLookback { get; set; }

        [Parameter("Min Impulse ATR",   DefaultValue = 0.8)]
        public double MinImpulseATR { get; set; }

        [Parameter("Risk %",            DefaultValue = 0.5)]
        public double RiskPercent { get; set; }

        [Parameter("Max Lots",          DefaultValue = 0.5)]
        public double MaxLots { get; set; }

        [Parameter("Max SL Pips (0=off)", DefaultValue = 150)]
        public double MaxSLPips { get; set; }

        // ── Custom SL / TP override ───────────────────────────────────────────
        [Parameter("Custom SL pips (0 = swing-based)", DefaultValue = 0)]
        public double CustomSL { get; set; }

        [Parameter("Custom TP pips (0 = swing-based)", DefaultValue = 0)]
        public double CustomTP { get; set; }

        // ── Cooldown parameter ────────────────────────────────────────────────
        [Parameter("Cooldown ATR Multiplier", DefaultValue = 1.5, MinValue = 0.5, MaxValue = 5.0)]
        public double CooldownAtrMultiplier { get; set; }

        // ── Private state ─────────────────────────────────────────────────────
        private ExponentialMovingAverage _emaFast;
        private ExponentialMovingAverage _emaSlow;
        private AverageTrueRange         _atr;

        // Setup state
        private bool      _setupActive;
        private TradeType _setupType;
        private double    _fibLow, _fibHigh;
        private double    _sl, _tp;
        private int       _setupBarIndex;

        // Swing anchors saved AT SETUP ACTIVATION (not at close)
        private double    _setupSwingHigh;
        private double    _setupSwingLow;

        // Cooldown state
        private bool      _inCooldown;
        private double    _cooldownSwingHigh;   // anchor: swing high when trade opened
        private double    _cooldownSwingLow;    // anchor: swing low when trade opened

        private const string BotLabel = "XAU_FIB_COOL_V1";

        // ── Initialisation ────────────────────────────────────────────────────
        protected override void OnStart()
        {
            _emaFast = Indicators.ExponentialMovingAverage(Bars.ClosePrices, EmaFast);
            _emaSlow = Indicators.ExponentialMovingAverage(Bars.ClosePrices, EmaSlow);
            _atr     = Indicators.AverageTrueRange(AtrPeriod, MovingAverageType.Simple);

            // Subscribe to close event — this is how cTrader signals a trade closed
            Positions.Closed += OnPositionClosed;

            _inCooldown     = false;
            _setupActive    = false;
            _setupSwingHigh = double.MinValue;
            _setupSwingLow  = double.MaxValue;
        }

        // ── OnBar: setup detection ────────────────────────────────────────────
        protected override void OnBar()
        {
            int i = Bars.Count - 2;
            if (i < SwingLookback + 5)
                return;

            if (!IsLondonOrNY())
                return;

            // ── Gate A: one trade at a time ───────────────────────────────────
            if (Positions.Find(BotLabel, SymbolName) != null || _setupActive)
                return;

            // ── Gate B: swing-based cooldown ──────────────────────────────────
            if (_inCooldown && !TryLiftCooldown(i))
                return;

            // ── Indicators ────────────────────────────────────────────────────
            bool bullishTrend = _emaFast.Result[i] > _emaSlow.Result[i];
            bool bearishTrend = _emaFast.Result[i] < _emaSlow.Result[i];

            double high = double.MinValue;
            double low  = double.MaxValue;
            for (int x = Math.Max(0, i - SwingLookback); x <= i; x++)
            {
                high = Math.Max(high, Bars.HighPrices[x]);
                low  = Math.Min(low,  Bars.LowPrices[x]);
            }

            double impulse = high - low;
            if (impulse < _atr.Result[i] * MinImpulseATR)
                return;

            // ── Setup activation ──────────────────────────────────────────────
            if (bullishTrend && IsBullishImpulse(i))
            {
                double f50  = high - impulse * 0.50;
                double f618 = high - impulse * 0.618;
                double sl   = Bars.LowPrices[i]  - _atr.Result[i] * 0.8;
                double tp   = high + _atr.Result[i] * 1.5;

                // Save swing anchor for cooldown (recorded at activation, not at close)
                _setupSwingHigh = high;
                _setupSwingLow  = low;

                ActivateSetup(TradeType.Buy,
                    Math.Min(f50, f618), Math.Max(f50, f618),
                    sl, tp, i);
            }
            else if (bearishTrend && IsBearishImpulse(i))
            {
                double f50  = low + impulse * 0.50;
                double f618 = low + impulse * 0.618;
                double sl   = Bars.HighPrices[i] + _atr.Result[i] * 0.8;
                double tp   = low - _atr.Result[i] * 1.5;

                // Save swing anchor for cooldown
                _setupSwingHigh = high;
                _setupSwingLow  = low;

                ActivateSetup(TradeType.Sell,
                    Math.Min(f50, f618), Math.Max(f50, f618),
                    sl, tp, i);
            }
        }

        // ── OnTick: entry trigger ─────────────────────────────────────────────
        protected override void OnTick()
        {
            if (!_setupActive || Positions.Find(BotLabel, SymbolName) != null)
                return;

            // Setup expires after setup_expiry_bars (use 8 for H1, adjust as needed)
            if (Bars.Count - 2 > _setupBarIndex + 8)
            {
                ResetSetup();
                return;
            }

            double triggerPrice = _setupType == TradeType.Buy ? Symbol.Ask : Symbol.Bid;

            if (triggerPrice >= _fibLow && triggerPrice <= _fibHigh)
            {
                ExecuteTrade(_setupType, _sl, _tp);
                ResetSetup();
            }
        }

        // ── Cooldown logic ────────────────────────────────────────────────────

        /// <summary>
        /// Called when a position labelled BotLabel on this symbol closes.
        /// Starts the swing-based cooldown using the SETUP ACTIVATION swing as anchor.
        /// </summary>
        private void OnPositionClosed(PositionClosedEventArgs args)
        {
            var p = args.Position;
            if (p == null)                                               return;
            if (p.SymbolName != SymbolName)                              return;
            if (!string.Equals(p.Label, BotLabel, StringComparison.Ordinal)) return;

            // Anchor = swing at the time the setup was ACTIVATED (not at close)
            // This anchors the cooldown to the structural move that caused the trade.
            _inCooldown        = true;
            _cooldownSwingHigh = _setupSwingHigh;
            _cooldownSwingLow  = _setupSwingLow;
        }

        /// <summary>
        /// Checks whether the current swing has moved far enough beyond the
        /// cooldown anchor to warrant a new setup attempt.
        /// Returns true if cooldown has been lifted (new swing confirmed).
        /// </summary>
        private bool TryLiftCooldown(int i)
        {
            if (!_inCooldown)
                return true;

            double atrVal = _atr.Result[i];
            if (atrVal <= 0)
                return false;   // Can't evaluate — stay locked

            double currHigh = double.MinValue;
            double currLow  = double.MaxValue;
            for (int x = Math.Max(0, i - SwingLookback); x <= i; x++)
            {
                currHigh = Math.Max(currHigh, Bars.HighPrices[x]);
                currLow  = Math.Min(currLow,  Bars.LowPrices[x]);
            }

            double margin = atrVal * CooldownAtrMultiplier;

            bool newHighFormed = currHigh > _cooldownSwingHigh + margin;
            bool newLowFormed  = currLow  < _cooldownSwingLow  - margin;

            if (newHighFormed || newLowFormed)
            {
                _inCooldown = false;   // New structure confirmed — lift cooldown
                return true;
            }

            return false;   // Cooldown still active
        }

        // ── Setup helpers ─────────────────────────────────────────────────────
        private void ActivateSetup(TradeType type, double fLow, double fHigh,
                                   double slBase, double tpBase, int barIndex)
        {
            _setupType     = type;
            _fibLow        = fLow;
            _fibHigh       = fHigh;
            _sl            = slBase;
            _tp            = tpBase;
            _setupBarIndex = barIndex;
            _setupActive   = true;
        }

        private void ResetSetup() { _setupActive = false; }

        // ── Trade execution ───────────────────────────────────────────────────
        private void ExecuteTrade(TradeType type, double slBasePrice, double tpBasePrice)
        {
            double entryPrice = type == TradeType.Buy ? Symbol.Ask : Symbol.Bid;

            double finalSL = slBasePrice;
            double finalTP = tpBasePrice;

            // Custom SL/TP override
            if (CustomSL > 0)
                finalSL = type == TradeType.Buy
                    ? entryPrice - CustomSL * Symbol.PipSize
                    : entryPrice + CustomSL * Symbol.PipSize;

            if (CustomTP > 0)
                finalTP = type == TradeType.Buy
                    ? entryPrice + CustomTP * Symbol.PipSize
                    : entryPrice - CustomTP * Symbol.PipSize;

            // Hard max SL cap — brings SL closer if swing-based SL is too wide
            if (MaxSLPips > 0)
            {
                double maxDist = MaxSLPips * Symbol.PipSize;
                if (type == TradeType.Buy)
                    finalSL = Math.Max(finalSL, entryPrice - maxDist);
                else
                    finalSL = Math.Min(finalSL, entryPrice + maxDist);
            }

            double riskPips = Math.Abs(entryPrice - finalSL) / Symbol.PipSize;
            if (riskPips < 5)
                return;

            double riskMoney    = Account.Balance * (RiskPercent / 100.0);
            double volumeUnits  = riskMoney / (riskPips * Symbol.PipValue);
            volumeUnits = Math.Min(volumeUnits, Symbol.QuantityToVolumeInUnits(MaxLots));
            volumeUnits = Symbol.NormalizeVolumeInUnits(volumeUnits);

            var result = ExecuteMarketOrder(type, SymbolName, volumeUnits, BotLabel);
            if (result == null || !result.IsSuccessful || result.Position == null)
                return;

            ModifyPosition(result.Position, finalSL, finalTP, ProtectionType.Absolute);
        }

        // ── Utility helpers ───────────────────────────────────────────────────
        private bool IsBullishImpulse(int i) =>
            Bars.ClosePrices[i] > Bars.OpenPrices[i] &&
            (Bars.ClosePrices[i] - Bars.OpenPrices[i]) > _atr.Result[i] * 0.4;

        private bool IsBearishImpulse(int i) =>
            Bars.ClosePrices[i] < Bars.OpenPrices[i] &&
            (Bars.OpenPrices[i] - Bars.ClosePrices[i]) > _atr.Result[i] * 0.4;

        private bool IsLondonOrNY()
        {
            int h = Server.Time.Hour;
            return h >= 7 && h <= 21;
        }
    }
}
