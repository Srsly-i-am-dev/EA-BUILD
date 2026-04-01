
class FibRegime7(cBot):
    EmaFast = Parameter(default=50, description="Fast EMA period")
    EmaSlow = Parameter(default=200, description="Slow EMA period")
    AtrPeriod = Parameter(default=14, description="ATR period (fast)")
    SwingLookback = Parameter(default=14, description="Swing lookback bars")
    MinImpulseATR = Parameter(default=0.9, description="Min impulse as ATR multiple")
    RiskPercent = Parameter(default=1.2, description="Risk % of balance per trade")
    MaxLots = Parameter(default=0.30, description="Max position size in lots")
    TradeLabel = Parameter(default="FIB_V4", description="Trade label")

    MinSLPips = Parameter(default=120.0, description="Minimum SL in pips (0=off)")
    MaxRR = Parameter(default=6.0, description="Maximum risk:reward ratio (0=off)")

    RiskMode = Parameter(default=2, description="0=Original 1=ATR 2=MultOriginal 3=CustomPips")
    CustomSL = Parameter(default=0.0, description="Custom SL pips (0=ignore)")
    CustomTP = Parameter(default=0.0, description="Custom TP pips (0=ignore)")
    AtrSLMult = Parameter(default=1.0, description="ATR SL multiplier")
    AtrTPMult = Parameter(default=1.5, description="ATR TP multiplier")
    SLMultiplier = Parameter(default=0.85, description="SL distance multiplier")
    TPMultiplier = Parameter(default=1.90, description="TP distance multiplier")

    RegimeBlockerEnabled = Parameter(default=True, description="Enable regime blocker")
    AtrSlowPeriod = Parameter(default=50, description="Slow ATR period")
    MinVolatilityRatio = Parameter(default=0.80, description="Min ATR14/ATR50 ratio")
    EmaSlopeLookback = Parameter(default=10, description="EMA slope lookback bars")
    MinEmaSlopeNorm = Parameter(default=0.30, description="Min EMA slope norm")
    MinImpulseBodyRatio = Parameter(default=0.55, description="Min candle body/range ratio")

    VolAdaptiveEnabled = Parameter(default=True, description="Enable vol-adaptive scaling")
    VolFactorClampMin = Parameter(default=0.80, description="Min vol factor clamp")
    VolFactorClampMax = Parameter(default=1.40, description="Max vol factor clamp")

    MaxDrawdownPercent = Parameter(default=20.0, description="Max drawdown % before halt")
    DDBasis = Parameter(default=0, description="0=FromPeakEquity 1=FromStartBalance")
    KillSwitchClosePos = Parameter(default=True, description="Close positions on kill switch")
    KillSwitchStopBot = Parameter(default=True, description="Stop bot on kill switch")

    Insurance = Parameter(default=0, description="0=Off 1=Hedge 2=PartialClose")
    InsuranceTriggerFrac = Parameter(default=0.80, description="Trigger at % of SL distance")
    RegimeBreakVolRatio = Parameter(default=0.75, description="Regime break ATR14/ATR50 threshold")
    RegimeBreakSlopeNorm = Parameter(default=0.20, description="Regime break EMA slope threshold")
    HedgeSizeFraction = Parameter(default=0.50, description="Hedge size as fraction of main")
    HedgeSLFracOfMain = Parameter(default=0.30, description="Hedge SL as fraction of main SL")
    HedgeTPToMainEntry = Parameter(default=True, description="Set hedge TP to main entry")
    PartialCloseFraction = Parameter(default=0.50, description="Fraction to close on partial close")

    UseMlFilter = Parameter(default=True, description="Enable XGBoost ML signal filter")
    MlModelPath = Parameter(default="xgboost_model.joblib", description="Path to trained .joblib model")
    MlMinProb = Parameter(default=0.55, description="Min ML probability to allow setup")
    MlFailOpen = Parameter(default=True, description="If True, allow setup when ML errors")
    ScaleRiskByMl = Parameter(default=False, description="Scale risk by ML confidence")
    MlMaxScale = Parameter(default=1.5, description="Max risk scale when ML confidence is high")

    def on_start(self):
        self._ema_fast = self.Indicators.ExponentialMovingAverage(self.Bars.ClosePrices, self.EmaFast)
        self._ema_slow = self.Indicators.ExponentialMovingAverage(self.Bars.ClosePrices, self.EmaSlow)
        self._atr_fast = self.Indicators.AverageTrueRange(self.AtrPeriod)
        self._atr_slow = self.Indicators.AverageTrueRange(self.AtrSlowPeriod)

        self._setup_active = False
        self._setup_type = None
        self._fib_low = 0.0
        self._fib_high = 0.0
        self._sl_base = 0.0
        self._tp_base = 0.0
        self._setup_bar_index = 0

        self._trading_halted = False
        self._start_balance = self.Account.Balance
        self._peak_equity = self.Account.Equity
        self._partial_close_done = set()

        self._ml_model = None
        self._last_ml_prob = 0.5
        if self.UseMlFilter:
            try:
                import joblib
                self._ml_model = joblib.load(self.MlModelPath)
                self.Print(f"[FibRegime7] ML model loaded from {self.MlModelPath}")
            except Exception as e:
                self.Print(f"[FibRegime7] ML load failed: {e}")

    @property
    def _hedge_label(self):
        return self.TradeLabel + "_H"

    def on_bar(self):
        if self._check_kill_switch():
            return

        i = len(self.Bars) - 2
        min_bars = max(self.SwingLookback + 5, self.EmaSlopeLookback + 5, self.AtrSlowPeriod + 5)
        if i < min_bars:
            return
        if not self._is_london_or_ny():
            return
        if self.Positions.Find(self.TradeLabel, self.SymbolName) is not None:
            return
        if self._setup_active:
            return
        if self.RegimeBlockerEnabled and not self._regime_is_valid(i):
            return

        ema_fast_val = self._ema_fast.Result[i]
        ema_slow_val = self._ema_slow.Result[i]
        bullish_trend = ema_fast_val > ema_slow_val
        bearish_trend = ema_fast_val < ema_slow_val

        high = max(self.Bars.HighPrices[x] for x in range(i - self.SwingLookback, i + 1))
        low = min(self.Bars.LowPrices[x] for x in range(i - self.SwingLookback, i + 1))
        impulse = high - low
        atr_val = self._atr_fast.Result[i]
        if impulse < atr_val * self.MinImpulseATR:
            return

        if self.UseMlFilter:
            if not self._ml_allow(i, atr_val, ema_fast_val, ema_slow_val, high, low):
                return

        if bullish_trend and self._is_bullish_impulse(i, atr_val):
            f50 = high - impulse * 0.50
            f618 = high - impulse * 0.618
            self._activate_setup(TradeType.Buy, min(f50, f618), max(f50, f618), self.Bars.LowPrices[i] - atr_val * 0.8, high + atr_val * 1.5, i)
        elif bearish_trend and self._is_bearish_impulse(i, atr_val):
            f50 = low + impulse * 0.50
            f618 = low + impulse * 0.618
            self._activate_setup(TradeType.Sell, min(f50, f618), max(f50, f618), self.Bars.HighPrices[i] + atr_val * 0.8, low - atr_val * 1.5, i)

    def on_tick(self):
        if self._check_kill_switch():
            return
        self._manage_insurance()

        if not self._setup_active:
            return
        if len(self.Bars) - 2 > self._setup_bar_index + 3:
            self._reset_setup()
            return
        if self.Positions.Find(self.TradeLabel, self.SymbolName) is not None:
            return

        price = self.Symbol.Bid if self._setup_type == TradeType.Buy else self.Symbol.Ask
        if self._fib_low <= price <= self._fib_high:
            self._execute_trade(self._setup_type, self._sl_base, self._tp_base)
            self._reset_setup()

    def _regime_is_valid(self, i):
        atr14 = self._atr_fast.Result[i]
        atr50 = self._atr_slow.Result[i]
        if atr14 <= 0 or atr50 <= 0:
            return False
        if atr14 / atr50 < self.MinVolatilityRatio:
            return False
        if i - self.EmaSlopeLookback < 0:
            return False
        ema_slope = abs(self._ema_fast.Result[i] - self._ema_fast.Result[i - self.EmaSlopeLookback])
        return (ema_slope / atr14) >= self.MinEmaSlopeNorm

    def _regime_has_broken(self, i):
        if i < max(self.AtrSlowPeriod + 2, self.EmaSlopeLookback + 2):
            return True
        atr14 = self._atr_fast.Result[i]
        atr50 = self._atr_slow.Result[i]
        if atr14 <= 0 or atr50 <= 0:
            return True
        if atr14 / atr50 < self.RegimeBreakVolRatio:
            return True
        ema_slope = abs(self._ema_fast.Result[i] - self._ema_fast.Result[i - self.EmaSlopeLookback])
        return (ema_slope / atr14) < self.RegimeBreakSlopeNorm

    def _check_kill_switch(self):
        if self._trading_halted:
            return True
        if self.MaxDrawdownPercent <= 0:
            return False
        self._peak_equity = max(self._peak_equity, self.Account.Equity)
        basis = self._peak_equity if self.DDBasis == 0 else self._start_balance
        if basis <= 0:
            return False
        dd = (basis - self.Account.Equity) / basis * 100.0
        if dd >= self.MaxDrawdownPercent:
            self._trading_halted = True
            self._reset_setup()
            if self.KillSwitchClosePos:
                self._close_positions_for_bot()
            if self.KillSwitchStopBot:
                self.Stop()
            return True
        return False

    def _close_positions_for_bot(self):
        for p in self.Positions:
            if p.SymbolName == self.SymbolName and p.Label in (self.TradeLabel, self._hedge_label):
                self.ClosePosition(p)

    def _manage_insurance(self):
        main = self.Positions.Find(self.TradeLabel, self.SymbolName)
        hedge = self.Positions.Find(self._hedge_label, self.SymbolName)
        if main is None:
            if hedge is not None:
                self.ClosePosition(hedge)
            return
        if hedge is not None and main.GrossProfit > 0:
            self.ClosePosition(hedge)
            return
        if self.Insurance == 0 or main.StopLoss is None:
            return
        sl_dist = abs(main.EntryPrice - main.StopLoss)
        if sl_dist <= 0:
            return
        adverse = max(0.0, main.EntryPrice - self.Symbol.Bid) if main.TradeType == TradeType.Buy else max(0.0, self.Symbol.Ask - main.EntryPrice)
        if (adverse / sl_dist) < self.InsuranceTriggerFrac:
            return
        i = len(self.Bars) - 2
        if not self._regime_has_broken(i):
            return
        if self.Insurance == 1 and hedge is None:
            self._open_hedge(main, sl_dist)
        elif self.Insurance == 2:
            key = str(main.Id)
            if key not in self._partial_close_done:
                self._do_partial_close(main)
                self._partial_close_done.add(key)

    def _open_hedge(self, main, main_sl_dist):
        hedge_frac = max(0.05, min(1.0, self.HedgeSizeFraction))
        hedge_vol = self.Symbol.NormalizeVolumeInUnits(float(main.VolumeInUnits) * hedge_frac)
        if hedge_vol <= 0:
            return
        hedge_type = TradeType.Sell if main.TradeType == TradeType.Buy else TradeType.Buy
        hedge_entry = self.Symbol.Ask if hedge_type == TradeType.Buy else self.Symbol.Bid
        hedge_sl_dist = max(main_sl_dist * max(0.05, min(1.0, self.HedgeSLFracOfMain)), 5 * self.Symbol.PipSize)
        hedge_sl = hedge_entry - hedge_sl_dist if hedge_type == TradeType.Buy else hedge_entry + hedge_sl_dist
        hedge_tp = main.EntryPrice if self.HedgeTPToMainEntry else (hedge_entry + hedge_sl_dist if hedge_type == TradeType.Buy else hedge_entry - hedge_sl_dist)
        res = self.ExecuteMarketOrder(hedge_type, self.SymbolName, hedge_vol, self._hedge_label)
        if res is None or not res.IsSuccessful or res.Position is None:
            return
        self.ModifyPosition(res.Position, round(hedge_sl, self.Symbol.Digits), round(hedge_tp, self.Symbol.Digits))

    def _do_partial_close(self, main):
        frac = max(0.05, min(0.95, self.PartialCloseFraction))
        vol_to_close = self.Symbol.NormalizeVolumeInUnits(float(main.VolumeInUnits) * frac)
        if vol_to_close > 0:
            self.ClosePosition(main, vol_to_close)

    def _apply_guardrails(self, trade_type, entry, sl, tp):
        pip = self.Symbol.PipSize
        sl_pips = abs(entry - sl) / pip
        if self.MinSLPips > 0 and sl_pips < self.MinSLPips:
            sl_pips = self.MinSLPips
            sl = entry - sl_pips * pip if trade_type == TradeType.Buy else entry + sl_pips * pip
        tp_pips = abs(tp - entry) / pip
        if self.MaxRR > 0:
            max_tp_pips = sl_pips * self.MaxRR
            if tp_pips > max_tp_pips:
                tp = entry + max_tp_pips * pip if trade_type == TradeType.Buy else entry - max_tp_pips * pip
        return round(sl, self.Symbol.Digits), round(tp, self.Symbol.Digits)

    def _execute_trade(self, trade_type, sl_base, tp_base):
        if self._trading_halted:
            return
        entry = self.Symbol.Ask if trade_type == TradeType.Buy else self.Symbol.Bid
        atr_val = self._atr_fast.Result[min(len(self.Bars) - 2, len(self._atr_fast.Result) - 1)]
        pip = self.Symbol.PipSize

        vol_factor = 1.0
        if self.VolAdaptiveEnabled:
            vol_factor = self._clamp(self._get_vol_ratio(len(self.Bars) - 2), self.VolFactorClampMin, self.VolFactorClampMax)

        sl = sl_base
        tp = tp_base
        mode = self.RiskMode
        if mode == 0:
            if self.CustomSL > 0:
                sl = entry - self.CustomSL * pip if trade_type == TradeType.Buy else entry + self.CustomSL * pip
            if self.CustomTP > 0:
                tp = entry + self.CustomTP * pip if trade_type == TradeType.Buy else entry - self.CustomTP * pip
        elif mode == 1:
            if atr_val <= 0:
                return
            sl_dist = max(atr_val * self.AtrSLMult, 5 * pip)
            tp_dist = max(atr_val * self.AtrTPMult, 5 * pip)
            sl = entry - sl_dist if trade_type == TradeType.Buy else entry + sl_dist
            tp = entry + tp_dist if trade_type == TradeType.Buy else entry - tp_dist
        elif mode == 2:
            orig_sl = max(abs(entry - sl_base), 5 * pip)
            orig_tp = max(abs(tp_base - entry), 5 * pip)
            sl_mult = max(0.01, self.SLMultiplier * (1.0 / vol_factor if vol_factor > 0 else 1.0))
            tp_mult = max(0.01, self.TPMultiplier * vol_factor)
            sl = entry - orig_sl * sl_mult if trade_type == TradeType.Buy else entry + orig_sl * sl_mult
            tp = entry + orig_tp * tp_mult if trade_type == TradeType.Buy else entry - orig_tp * tp_mult
        elif mode == 3:
            if self.CustomSL > 0:
                sl = entry - self.CustomSL * pip if trade_type == TradeType.Buy else entry + self.CustomSL * pip
            if self.CustomTP > 0:
                tp = entry + self.CustomTP * pip if trade_type == TradeType.Buy else entry - self.CustomTP * pip

        sl, tp = self._apply_guardrails(trade_type, entry, sl, tp)
        if trade_type == TradeType.Buy and (sl >= entry or tp <= entry):
            return
        if trade_type == TradeType.Sell and (sl <= entry or tp >= entry):
            return

        risk_pips = abs(entry - sl) / pip
        if risk_pips < 5:
            return
        risk_scale = self._risk_scale_from_ml()
        risk_money = self.Account.Balance * ((self.RiskPercent * risk_scale) / 100.0)
        volume = risk_money / (risk_pips * self.Symbol.PipValue)
        volume = min(volume, self.Symbol.QuantityToVolumeInUnits(self.MaxLots))
        volume = self.Symbol.NormalizeVolumeInUnits(volume)
        if volume <= 0:
            return
        res = self.ExecuteMarketOrder(trade_type, self.SymbolName, volume, self.TradeLabel)
        if res is None or not res.IsSuccessful or res.Position is None:
            return
        self.ModifyPosition(res.Position, sl, tp)

    def _activate_setup(self, trade_type, fib_low, fib_high, sl, tp, bar_index):
        self._setup_type = trade_type
        self._fib_low = fib_low
        self._fib_high = fib_high
        self._sl_base = sl
        self._tp_base = tp
        self._setup_bar_index = bar_index
        self._setup_active = True

    def _reset_setup(self):
        self._setup_active = False

    def _has_good_body_ratio(self, i):
        rng = self.Bars.HighPrices[i] - self.Bars.LowPrices[i]
        if rng <= 0:
            return False
        body = abs(self.Bars.ClosePrices[i] - self.Bars.OpenPrices[i])
        return (body / rng) >= self.MinImpulseBodyRatio

    def _is_bullish_impulse(self, i, atr_val):
        if not self._has_good_body_ratio(i):
            return False
        return self.Bars.ClosePrices[i] > self.Bars.OpenPrices[i] and (self.Bars.ClosePrices[i] - self.Bars.OpenPrices[i]) > atr_val * 0.4

    def _is_bearish_impulse(self, i, atr_val):
        if not self._has_good_body_ratio(i):
            return False
        return self.Bars.ClosePrices[i] < self.Bars.OpenPrices[i] and (self.Bars.OpenPrices[i] - self.Bars.ClosePrices[i]) > atr_val * 0.4

    def _ml_allow(self, i, atr_val, ema_fast_val, ema_slow_val, high, low):
        if self._ml_model is None:
            return True if self.MlFailOpen else False
        try:
            impulse = high - low
            atr_prev = self._atr_fast.Result[max(0, i - 10)]
            features = [[
                ema_fast_val / ema_slow_val if abs(ema_slow_val) > 1e-12 else 1.0,
                atr_val,
                impulse / atr_val if atr_val > 1e-12 else 0.0,
                atr_val / atr_prev if atr_prev > 1e-12 else 1.0,
            ]]
            prob = float(self._ml_model.predict_proba(features)[0][1])
            self._last_ml_prob = prob
            return prob >= self.MlMinProb
        except Exception:
            return True if self.MlFailOpen else False

    def _risk_scale_from_ml(self):
        if not self.ScaleRiskByMl:
            return 1.0
        if self._last_ml_prob <= self.MlMinProb:
            return 1.0
        span = max(1.0 - self.MlMinProb, 1e-9)
        t = min(max((self._last_ml_prob - self.MlMinProb) / span, 0.0), 1.0)
        return 1.0 + t * max(0.0, self.MlMaxScale - 1.0)

    def _get_vol_ratio(self, i):
        a14 = self._atr_fast.Result[i]
        a50 = self._atr_slow.Result[i]
        if a14 <= 0 or a50 <= 0:
            return 1.0
        return a14 / a50

    def _clamp(self, v, lo, hi):
        return max(lo, min(hi, v))

    def _is_london_or_ny(self):
        h = self.Server.Time.Hour
        return 7 <= h <= 21
