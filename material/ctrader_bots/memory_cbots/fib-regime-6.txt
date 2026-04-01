using cAlgo.API;
using cAlgo.API.Indicators;
using System;
using System.Collections.Generic;

namespace cAlgo.Robots
{
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class fib_regime_6 : Robot
    {
        // -----------------------------
        // Core Strategy Parameters (BASE LOGIC)
        // -----------------------------
        [Parameter("EMA Fast", DefaultValue = 50)]
        public int EmaFast { get; set; }

        [Parameter("EMA Slow", DefaultValue = 200)]
        public int EmaSlow { get; set; }

        [Parameter("ATR Period", DefaultValue = 14)]
        public int AtrPeriod { get; set; }

        [Parameter("Swing Lookback", DefaultValue = 14)]
        public int SwingLookback { get; set; }

        [Parameter("Min Impulse ATR", DefaultValue = 0.9)]
        public double MinImpulseATR { get; set; }

        [Parameter("Risk %", DefaultValue = 1.2)]
        public double RiskPercent { get; set; }

        [Parameter("Max Lots", DefaultValue = 0.30)]
        public double MaxLots { get; set; }

        [Parameter("Trade Label", DefaultValue = "FIB_V4")]
        public string TradeLabel { get; set; }

        // -----------------------------
        // Risk Mode
        // -----------------------------
        public enum RiskMode
        {
            OriginalStrategy = 0,
            AtrFromEntry = 1,
            MultiplyOriginalDistances = 2,
            CustomPips = 3
        }

        [Parameter("Risk Mode", DefaultValue = RiskMode.MultiplyOriginalDistances)]
        public RiskMode RiskManagement { get; set; }

        [Parameter("Custom Stop Loss (pips, 0=ignore)", DefaultValue = 0)]
        public double CustomSL { get; set; }

        [Parameter("Custom Take Profit (pips, 0=ignore)", DefaultValue = 0)]
        public double CustomTP { get; set; }

        [Parameter("ATR SL Mult (AtrFromEntry)", DefaultValue = 1.0)]
        public double AtrSLMult { get; set; }

        [Parameter("ATR TP Mult (AtrFromEntry)", DefaultValue = 1.5)]
        public double AtrTPMult { get; set; }

        // Version 4 multipliers
        [Parameter("SL Mult (MultiplyOriginalDistances)", DefaultValue = 0.85)]
        public double SLMultiplier { get; set; }

        [Parameter("TP Mult (MultiplyOriginalDistances)", DefaultValue = 1.90)]
        public double TPMultiplier { get; set; }

        // -----------------------------
        // Regime Blocker
        // -----------------------------
        [Parameter("Regime Blocker Enabled", DefaultValue = true)]
        public bool RegimeBlockerEnabled { get; set; }

        [Parameter("ATR Slow Period (Regime)", DefaultValue = 50)]
        public int AtrSlowPeriod { get; set; }

        [Parameter("Min ATR14/ATR50", DefaultValue = 0.80)]
        public double MinVolatilityRatio { get; set; }

        [Parameter("EMA Slope Lookback (bars)", DefaultValue = 10)]
        public int EmaSlopeLookback { get; set; }

        [Parameter("Min EMA Slope (ATR-norm)", DefaultValue = 0.30)]
        public double MinEmaSlopeNorm { get; set; }

        [Parameter("Min Impulse Body Ratio", DefaultValue = 0.55)]
        public double MinImpulseBodyRatio { get; set; }

        // -----------------------------
        // Volatility-Adaptive SL/TP Scaler
        // -----------------------------
        [Parameter("Vol-Adaptive Enabled", DefaultValue = true)]
        public bool VolAdaptiveEnabled { get; set; }

        [Parameter("VolFactor Clamp Min", DefaultValue = 0.80)]
        public double VolFactorClampMin { get; set; }

        [Parameter("VolFactor Clamp Max", DefaultValue = 1.40)]
        public double VolFactorClampMax { get; set; }

        // -----------------------------
        // Drawdown Kill Switch
        // -----------------------------
        public enum DrawdownBasis
        {
            FromPeakEquity = 0,
            FromStartBalance = 1
        }

        [Parameter("Max Drawdown % (0=off)", DefaultValue = 20)]
        public double MaxDrawdownPercent { get; set; }

        [Parameter("DD Basis", DefaultValue = DrawdownBasis.FromPeakEquity)]
        public DrawdownBasis DDBasis { get; set; }

        [Parameter("KillSwitch: Close Positions", DefaultValue = true)]
        public bool KillSwitchClosePositions { get; set; }

        [Parameter("KillSwitch: Stop cBot", DefaultValue = true)]
        public bool KillSwitchStopBot { get; set; }

        // -----------------------------
        // Insurance: Hedge OR Partial Close
        // -----------------------------
        public enum InsuranceMode
        {
            Off = 0,
            Hedge = 1,
            PartialClose = 2
        }

        [Parameter("Insurance Mode", DefaultValue = InsuranceMode.Off)]
        public InsuranceMode Insurance { get; set; }

        [Parameter("Trigger at % of SL distance", DefaultValue = 0.80)]
        public double InsuranceTriggerAtSLFrac { get; set; }

        [Parameter("RegimeBreak ATR14/ATR50", DefaultValue = 0.75)]
        public double RegimeBreakVolRatio { get; set; }

        [Parameter("RegimeBreak EMA Slope", DefaultValue = 0.20)]
        public double RegimeBreakSlopeNorm { get; set; }

        // Hedge settings
        [Parameter("Hedge Size Fraction", DefaultValue = 0.50)]
        public double HedgeSizeFraction { get; set; }

        [Parameter("Hedge SL Fraction of Main SL", DefaultValue = 0.30)]
        public double HedgeSLFracOfMain { get; set; }

        [Parameter("Hedge TP = Main Entry", DefaultValue = true)]
        public bool HedgeTPToMainEntry { get; set; }

        // Partial close settings
        [Parameter("Partial Close Fraction", DefaultValue = 0.50)]
        public double PartialCloseFraction { get; set; }

        // -----------------------------
        // Indicators / State
        // -----------------------------
        private ExponentialMovingAverage emaFast, emaSlow;
        private AverageTrueRange atrFast, atrSlow;

        // setup state
        private bool setupActive;
        private TradeType setupType;
        private double fibLow, fibHigh;
        private double slBase, tpBase;
        private int setupBarIndex;

        // kill switch state
        private bool tradingHalted;
        private double startBalance;
        private double peakEquity;

        private string HedgeLabel => TradeLabel + "_H";

        // Build-proof marker store
        private readonly HashSet<string> _partialCloseDone = new HashSet<string>();

        protected override void OnStart()
        {
            emaFast = Indicators.ExponentialMovingAverage(Bars.ClosePrices, EmaFast);
            emaSlow = Indicators.ExponentialMovingAverage(Bars.ClosePrices, EmaSlow);

            atrFast = Indicators.AverageTrueRange(AtrPeriod, MovingAverageType.Simple);
            atrSlow = Indicators.AverageTrueRange(AtrSlowPeriod, MovingAverageType.Simple);

            startBalance = Account.Balance;
            peakEquity = Account.Equity;

            tradingHalted = false;
            setupActive = false;
        }

        protected override void OnBar()
        {
            if (CheckAndApplyKillSwitch())
                return;

            int i = Bars.Count - 2;
            if (i < Math.Max(SwingLookback + 5, EmaSlopeLookback + 5) || i < AtrSlowPeriod + 5)
                return;

            if (!IsLondonOrNY())
                return;

            // one main position at a time
            if (Positions.Find(TradeLabel, SymbolName) != null || setupActive)
                return;

            // Regime blocker blocks entries only
            if (RegimeBlockerEnabled && !RegimeIsValid(i))
                return;

            bool bullishTrend = emaFast.Result[i] > emaSlow.Result[i];
            bool bearishTrend = emaFast.Result[i] < emaSlow.Result[i];

            double high = double.MinValue;
            double low = double.MaxValue;

            for (int x = i - SwingLookback; x <= i; x++)
            {
                high = Math.Max(high, Bars.HighPrices[x]);
                low = Math.Min(low, Bars.LowPrices[x]);
            }

            double impulse = high - low;
            if (impulse < atrFast.Result[i] * MinImpulseATR)
                return;

            if (bullishTrend && IsBullishImpulse(i))
            {
                double f50 = high - impulse * 0.50;
                double f618 = high - impulse * 0.618;

                ActivateSetup(
                    TradeType.Buy,
                    Math.Min(f50, f618),
                    Math.Max(f50, f618),
                    Bars.LowPrices[i] - atrFast.Result[i] * 0.8, // base SL
                    high + atrFast.Result[i] * 1.5,             // base TP
                    i
                );
            }
            else if (bearishTrend && IsBearishImpulse(i))
            {
                double f50 = low + impulse * 0.50;
                double f618 = low + impulse * 0.618;

                ActivateSetup(
                    TradeType.Sell,
                    Math.Min(f50, f618),
                    Math.Max(f50, f618),
                    Bars.HighPrices[i] + atrFast.Result[i] * 0.8,
                    low - atrFast.Result[i] * 1.5,
                    i
                );
            }
        }

        protected override void OnTick()
        {
            if (CheckAndApplyKillSwitch())
                return;

            // manage insurance continuously
            ManageInsurance();

            if (!setupActive)
                return;

            // setup valid for 3 bars
            if (Bars.Count - 2 > setupBarIndex + 3)
            {
                ResetSetup();
                return;
            }

            // no new entry if main position exists
            if (Positions.Find(TradeLabel, SymbolName) != null)
                return;

            double price = setupType == TradeType.Buy ? Symbol.Bid : Symbol.Ask;

            if (price >= fibLow && price <= fibHigh)
            {
                ExecuteTrade(setupType, slBase, tpBase);
                ResetSetup();
            }
        }

        private void ActivateSetup(TradeType type, double fLow, double fHigh, double slPriceBase, double tpPriceBase, int barIndex)
        {
            setupType = type;
            fibLow = fLow;
            fibHigh = fHigh;
            slBase = slPriceBase;
            tpBase = tpPriceBase;
            setupBarIndex = barIndex;
            setupActive = true;
        }

        private void ResetSetup() => setupActive = false;

        // -----------------------------
        // Regime Blocker
        // -----------------------------
        private bool RegimeIsValid(int i)
        {
            double atr14 = atrFast.Result[i];
            double atr50 = atrSlow.Result[i];
            if (atr14 <= 0 || atr50 <= 0)
                return false;

            double volRatio = atr14 / atr50;
            if (volRatio < MinVolatilityRatio)
                return false;

            if (i - EmaSlopeLookback < 0)
                return false;

            double emaSlope = Math.Abs(emaFast.Result[i] - emaFast.Result[i - EmaSlopeLookback]);
            double slopeNorm = emaSlope / atr14;
            if (slopeNorm < MinEmaSlopeNorm)
                return false;

            return true;
        }

        private bool HasGoodBodyRatio(int i)
        {
            double range = Bars.HighPrices[i] - Bars.LowPrices[i];
            if (range <= 0)
                return false;

            double body = Math.Abs(Bars.ClosePrices[i] - Bars.OpenPrices[i]);
            double bodyRatio = body / range;

            return bodyRatio >= MinImpulseBodyRatio;
        }

        // -----------------------------
        // Execution
        // -----------------------------
        private void ExecuteTrade(TradeType type, double slPriceBase, double tpPriceBase)
        {
            if (tradingHalted)
                return;

            double entryRef = type == TradeType.Buy ? Symbol.Ask : Symbol.Bid;

            // volatility factor used ONLY for scaling multipliers
            double volFactor = 1.0;
            if (VolAdaptiveEnabled)
                volFactor = Clamp(GetVolRatio(Bars.Count - 2), VolFactorClampMin, VolFactorClampMax);

            double slPrice = slPriceBase;
            double tpPrice = tpPriceBase;

            switch (RiskManagement)
            {
                case RiskMode.OriginalStrategy:
                    break;

                case RiskMode.AtrFromEntry:
                {
                    double atrVal = atrFast.Result[Bars.Count - 2];
                    if (atrVal <= 0)
                        return;

                    double slDist = Math.Max(atrVal * AtrSLMult, 5 * Symbol.PipSize);
                    double tpDist = Math.Max(atrVal * AtrTPMult, 5 * Symbol.PipSize);

                    if (type == TradeType.Buy)
                    {
                        slPrice = entryRef - slDist;
                        tpPrice = entryRef + tpDist;
                    }
                    else
                    {
                        slPrice = entryRef + slDist;
                        tpPrice = entryRef - tpDist;
                    }
                    break;
                }

                case RiskMode.MultiplyOriginalDistances:
                {
                    double origSLDist = Math.Abs(entryRef - slPriceBase);
                    double origTPDist = Math.Abs(tpPriceBase - entryRef);

                    origSLDist = Math.Max(origSLDist, 5 * Symbol.PipSize);
                    origTPDist = Math.Max(origTPDist, 5 * Symbol.PipSize);

                    double slMultEff = SLMultiplier;
                    double tpMultEff = TPMultiplier;

                    if (VolAdaptiveEnabled)
                    {
                        // tighten in compression, expand in expansion
                        slMultEff = SLMultiplier * (1.0 / volFactor);
                        tpMultEff = TPMultiplier * volFactor;
                    }

                    slMultEff = Math.Max(0.01, slMultEff);
                    tpMultEff = Math.Max(0.01, tpMultEff);

                    double slDist = origSLDist * slMultEff;
                    double tpDist = origTPDist * tpMultEff;

                    if (type == TradeType.Buy)
                    {
                        slPrice = entryRef - slDist;
                        tpPrice = entryRef + tpDist;
                    }
                    else
                    {
                        slPrice = entryRef + slDist;
                        tpPrice = entryRef - tpDist;
                    }
                    break;
                }

                case RiskMode.CustomPips:
                {
                    if (CustomSL > 0)
                        slPrice = type == TradeType.Buy ? entryRef - CustomSL * Symbol.PipSize : entryRef + CustomSL * Symbol.PipSize;

                    if (CustomTP > 0)
                        tpPrice = type == TradeType.Buy ? entryRef + CustomTP * Symbol.PipSize : entryRef - CustomTP * Symbol.PipSize;
                    break;
                }
            }

            // Override: if OriginalStrategy but custom pips provided
            if (RiskManagement == RiskMode.OriginalStrategy)
            {
                if (CustomSL > 0)
                    slPrice = type == TradeType.Buy ? entryRef - CustomSL * Symbol.PipSize : entryRef + CustomSL * Symbol.PipSize;

                if (CustomTP > 0)
                    tpPrice = type == TradeType.Buy ? entryRef + CustomTP * Symbol.PipSize : entryRef - CustomTP * Symbol.PipSize;
            }

            slPrice = NormalizePrice(slPrice);
            tpPrice = NormalizePrice(tpPrice);

            // sanity
            if (type == TradeType.Buy)
            {
                if (slPrice >= entryRef || tpPrice <= entryRef)
                    return;
            }
            else
            {
                if (slPrice <= entryRef || tpPrice >= entryRef)
                    return;
            }

            // sizing uses SL distance (pips)
            double slPipsForSizing = Math.Abs(entryRef - slPrice) / Symbol.PipSize;
            if (slPipsForSizing < 5)
                return;

            double riskMoney = Account.Balance * (RiskPercent / 100.0);
            double volumeUnitsD = riskMoney / (slPipsForSizing * Symbol.PipValue);

            // cap by max lots
            double maxUnits = Symbol.QuantityToVolumeInUnits(MaxLots);
            volumeUnitsD = Math.Min(volumeUnitsD, maxUnits);

            long volumeUnits = ToVolumeUnits(volumeUnitsD);
            if (volumeUnits <= 0)
                return;

            var res = ExecuteMarketOrder(type, SymbolName, volumeUnits, TradeLabel);
            if (!res.IsSuccessful || res.Position == null)
                return;

            ModifyPosition(res.Position, slPrice, tpPrice, ProtectionType.Absolute);
        }

        // -----------------------------
        // Insurance: Hedge / Partial Close
        // -----------------------------
        private void ManageInsurance()
        {
            var main = Positions.Find(TradeLabel, SymbolName);
            var hedge = Positions.Find(HedgeLabel, SymbolName);

            // If main gone but hedge remains -> close hedge
            if (main == null)
            {
                if (hedge != null)
                    ClosePosition(hedge);
                return;
            }

            // Preserve winners: if hedge exists and main turns positive -> kill hedge
            if (hedge != null && main.GrossProfit > 0)
            {
                ClosePosition(hedge);
                return;
            }

            if (Insurance == InsuranceMode.Off)
                return;

            if (!main.StopLoss.HasValue)
                return;

            // Trigger only near SL distance AND regime break
            double entry = main.EntryPrice;
            double sl = main.StopLoss.Value;

            double slDist = Math.Abs(entry - sl);
            if (slDist <= 0)
                return;

            double adverseMove = GetAdverseMoveFromEntry(main);
            double fracToSL = adverseMove / slDist;

            if (fracToSL < InsuranceTriggerAtSLFrac)
                return;

            if (!RegimeHasBrokenNow())
                return;

            if (Insurance == InsuranceMode.Hedge)
            {
                if (hedge != null)
                    return;

                OpenHedge(main, slDist);
            }
            else if (Insurance == InsuranceMode.PartialClose)
            {
                string key = Convert.ToString(main.Id);
                if (_partialCloseDone.Contains(key))
                    return;

                DoPartialClose(main);
                _partialCloseDone.Add(key);
            }
        }

        private void OpenHedge(Position main, double mainSlDist)
        {
            double hedgeFrac = Clamp(HedgeSizeFraction, 0.05, 1.0);

            double mainUnits = Convert.ToDouble(main.VolumeInUnits);
            long hedgeVol = ToVolumeUnits(mainUnits * hedgeFrac);
            if (hedgeVol <= 0)
                return;

            TradeType hedgeType = main.TradeType == TradeType.Buy ? TradeType.Sell : TradeType.Buy;
            double hedgeEntryRef = hedgeType == TradeType.Buy ? Symbol.Ask : Symbol.Bid;

            double hedgeSlDist = Math.Max(mainSlDist * Clamp(HedgeSLFracOfMain, 0.05, 1.0), 5 * Symbol.PipSize);

            double hedgeSL = hedgeType == TradeType.Buy ? hedgeEntryRef - hedgeSlDist : hedgeEntryRef + hedgeSlDist;

            double hedgeTP = HedgeTPToMainEntry
                ? main.EntryPrice
                : (hedgeType == TradeType.Buy ? hedgeEntryRef + hedgeSlDist : hedgeEntryRef - hedgeSlDist);

            hedgeSL = NormalizePrice(hedgeSL);
            hedgeTP = NormalizePrice(hedgeTP);

            var res = ExecuteMarketOrder(hedgeType, SymbolName, hedgeVol, HedgeLabel);
            if (!res.IsSuccessful || res.Position == null)
                return;

            ModifyPosition(res.Position, hedgeSL, hedgeTP, ProtectionType.Absolute);
        }

        private void DoPartialClose(Position main)
        {
            double frac = Clamp(PartialCloseFraction, 0.05, 0.95);

            double mainUnits = Convert.ToDouble(main.VolumeInUnits);
            long volToClose = ToVolumeUnits(mainUnits * frac);
            if (volToClose <= 0)
                return;

            if (volToClose >= mainUnits)
                volToClose = ToVolumeUnits(mainUnits * 0.5);

            if (volToClose <= 0)
                return;

            ClosePosition(main, volToClose);
        }

        private double GetAdverseMoveFromEntry(Position p)
        {
            if (p.TradeType == TradeType.Buy)
                return Math.Max(0, p.EntryPrice - Symbol.Bid);
            else
                return Math.Max(0, Symbol.Ask - p.EntryPrice);
        }

        private bool RegimeHasBrokenNow()
        {
            int i = Bars.Count - 2;
            if (i < Math.Max(AtrSlowPeriod + 2, EmaSlopeLookback + 2))
                return true;

            double atr14 = atrFast.Result[i];
            double atr50 = atrSlow.Result[i];
            if (atr14 <= 0 || atr50 <= 0)
                return true;

            double volRatio = atr14 / atr50;
            if (volRatio < RegimeBreakVolRatio)
                return true;

            double emaSlope = Math.Abs(emaFast.Result[i] - emaFast.Result[i - EmaSlopeLookback]);
            double slopeNorm = emaSlope / atr14;
            if (slopeNorm < RegimeBreakSlopeNorm)
                return true;

            return false;
        }

        // -----------------------------
        // Kill Switch
        // -----------------------------
        private bool CheckAndApplyKillSwitch()
        {
            if (tradingHalted)
                return true;

            if (MaxDrawdownPercent <= 0)
                return false;

            peakEquity = Math.Max(peakEquity, Account.Equity);

            double basis = (DDBasis == DrawdownBasis.FromPeakEquity) ? peakEquity : startBalance;
            if (basis <= 0)
                return false;

            double dd = (basis - Account.Equity) / basis * 100.0;
            if (dd >= MaxDrawdownPercent)
            {
                tradingHalted = true;
                ResetSetup();

                if (KillSwitchClosePositions)
                    ClosePositionsForThisBot();

                if (KillSwitchStopBot)
                    Stop();

                return true;
            }

            return false;
        }

        private void ClosePositionsForThisBot()
        {
            foreach (var p in Positions)
            {
                if (p.SymbolName == SymbolName && (p.Label == TradeLabel || p.Label == HedgeLabel))
                    ClosePosition(p);
            }
        }

        // -----------------------------
        // Impulse Checks
        // -----------------------------
        private bool IsBullishImpulse(int i)
        {
            if (!HasGoodBodyRatio(i))
                return false;

            return Bars.ClosePrices[i] > Bars.OpenPrices[i] &&
                   (Bars.ClosePrices[i] - Bars.OpenPrices[i]) > atrFast.Result[i] * 0.4;
        }

        private bool IsBearishImpulse(int i)
        {
            if (!HasGoodBodyRatio(i))
                return false;

            return Bars.ClosePrices[i] < Bars.OpenPrices[i] &&
                   (Bars.OpenPrices[i] - Bars.ClosePrices[i]) > atrFast.Result[i] * 0.4;
        }

        // -----------------------------
        // Session Filter
        // -----------------------------
        private bool IsLondonOrNY()
        {
            int h = Server.Time.Hour;
            return h >= 7 && h <= 21;
        }

        // -----------------------------
        // Helpers
        // -----------------------------
        private double NormalizePrice(double price) => Math.Round(price, Symbol.Digits);

        private double GetVolRatio(int i)
        {
            double a1 = atrFast.Result[i];
            double a2 = atrSlow.Result[i];
            if (a1 <= 0 || a2 <= 0) return 1.0;
            return a1 / a2;
        }

        private double Clamp(double v, double lo, double hi)
        {
            if (v < lo) return lo;
            if (v > hi) return hi;
            return v;
        }

        /// <summary>
        /// Build-proof conversion: NormalizeVolumeInUnits may return double in your cTrader build.
        /// Avoids ALL implicit double->long conversion errors.
        /// </summary>
        private long ToVolumeUnits(double units)
        {
            if (double.IsNaN(units) || double.IsInfinity(units) || units <= 0)
                return 0;

            long raw = (long)Math.Round(units);

            // NormalizeVolumeInUnits may return double in your build
            double normD = Symbol.NormalizeVolumeInUnits(raw);
            long norm = (long)Math.Round(normD);

            double minD = Convert.ToDouble(Symbol.VolumeInUnitsMin);
            long minL = (long)Math.Ceiling(minD);

            if (norm < minL)
                return 0;

            return norm;
        }
    }
}
