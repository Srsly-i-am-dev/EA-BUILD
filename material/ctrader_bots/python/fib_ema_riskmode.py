from ctrader.algo.api import *


class FibEmaRiskMode(cBot):
    EmaFast = Parameter(default=50, description="EMA Fast")
    EmaSlow = Parameter(default=200, description="EMA Slow")
    AtrPeriod = Parameter(default=14, description="ATR Period")
    SwingLookback = Parameter(default=15, description="Swing Lookback")
    MinImpulseATR = Parameter(default=0.8, description="Min Impulse ATR")
    RiskPercent = Parameter(default=0.5, description="Risk % (fallback/base)")
    MaxLots = Parameter(default=0.5, description="Max Lots")
    CustomSL = Parameter(default=0.0, description="Custom SL pips (0=off)")
    CustomTP = Parameter(default=0.0, description="Custom TP pips (0=off)")

    RiskMode = Parameter(default=0, description="0=Original 1=ATR 2=MultOriginal 3=CustomPips")
    AtrSLMult = Parameter(default=1.0, description="ATR SL multiplier")
    AtrTPMult = Parameter(default=1.5, description="ATR TP multiplier")
    SLMultiplier = Parameter(default=1.0, description="SL distance multiplier")
    TPMultiplier = Parameter(default=1.0, description="TP distance multiplier")

    MaxDrawdownPercent = Parameter(default=0.0, description="Max drawdown % (0=off)")
    DDBasis = Parameter(default=0, description="0=FromPeakEquity 1=FromStartBalance")
    KillSwitchClosePos = Parameter(default=True, description="Close positions on kill switch")
    KillSwitchStopBot = Parameter(default=True, description="Stop bot on kill switch")
    TradeLabel = Parameter(default="XAU_FIB_ACTIVE_V2", description="Trade label")

    UseMlFilter = Parameter(default=True, description="Enable XGBoost ML signal filter")
    MlModelPath = Parameter(default="xgboost_model.joblib", description="Path to trained .joblib model")
    MlMinProb = Parameter(default=0.55, description="Min ML probability to allow setup")
    MlFailOpen = Parameter(default=True, description="If True, allow setup when ML errors")
    ScaleRiskByMl = Parameter(default=False, description="Scale risk by ML confidence")
    MlMaxScale = Parameter(default=1.5, description="Max risk scale when ML confidence is high")

    def on_start(self):
        self._ema_fast = self.Indicators.ExponentialMovingAverage(self.Bars.ClosePrices, self.EmaFast)
        self._ema_slow = self.Indicators.ExponentialMovingAverage(self.Bars.ClosePrices, self.EmaSlow)
        self._atr = self.Indicators.AverageTrueRange(self.AtrPeriod)

        self._setup_active = False
        self._setup_type = None
        self._fib_low = 0.0
        self._fib_high = 0.0
        self._sl = 0.0
        self._tp = 0.0
        self._setup_bar_index = 0

        self._trading_halted = False
        self._start_balance = self.Account.Balance
        self._peak_equity = self.Account.Equity

        self._ml_model = None
        self._last_ml_prob = 0.5
        if self.UseMlFilter:
            try:
                import joblib
                self._ml_model = joblib.load(self.MlModelPath)
                self.Print(f"[FibEmaRiskMode] ML model loaded from {self.MlModelPath}")
            except Exception as e:
                self.Print(f"[FibEmaRiskMode] ML load failed: {e}")

    def on_bar(self):
        if self._check_kill_switch():
            return
        i = len(self.Bars) - 2
        if i < self.SwingLookback + 5:
            return
        if not self._is_london_or_ny():
            return
        if self._has_any_position() or self._setup_active:
            return

        ema_fast_val = self._ema_fast.Result[i]
        ema_slow_val = self._ema_slow.Result[i]
        bullish_trend = ema_fast_val > ema_slow_val
        bearish_trend = ema_fast_val < ema_slow_val
        high = max(self.Bars.HighPrices[x] for x in range(i - self.SwingLookback, i + 1))
        low = min(self.Bars.LowPrices[x] for x in range(i - self.SwingLookback, i + 1))
        impulse = high - low
        atr_val = self._atr.Result[i]
        if impulse < atr_val * self.MinImpulseATR:
            return

        if self.UseMlFilter:
            if not self._ml_allow(i, atr_val, ema_fast_val, ema_slow_val, high, low):
                return

        if bullish_trend and self._is_bullish_impulse(i, atr_val):
            f50 = high - impulse * 0.5
            f618 = high - impulse * 0.618
            self._activate_setup(TradeType.Buy, min(f50, f618), max(f50, f618), self.Bars.LowPrices[i] - atr_val * 0.8, high + atr_val * 1.5, i)
        elif bearish_trend and self._is_bearish_impulse(i, atr_val):
            f50 = low + impulse * 0.5
            f618 = low + impulse * 0.618
            self._activate_setup(TradeType.Sell, min(f50, f618), max(f50, f618), self.Bars.HighPrices[i] + atr_val * 0.8, low - atr_val * 1.5, i)

    def on_tick(self):
        if self._check_kill_switch():
            return
        if not self._setup_active or self._has_any_position():
            return
        if len(self.Bars) - 2 > self._setup_bar_index + 3:
            self._reset_setup()
            return
        price = self.Symbol.Bid if self._setup_type == TradeType.Buy else self.Symbol.Ask
        if self._fib_low <= price <= self._fib_high:
            self._execute_trade(self._setup_type, self._sl, self._tp)
            self._reset_setup()

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
            if p.SymbolName == self.SymbolName and p.Label == self.TradeLabel:
                self.ClosePosition(p)

    def _has_any_position(self):
        for _ in self.Positions:
            return True
        return False

    def _activate_setup(self, trade_type, fib_low, fib_high, sl, tp, bar_index):
        self._setup_type = trade_type
        self._fib_low = fib_low
        self._fib_high = fib_high
        self._sl = sl
        self._tp = tp
        self._setup_bar_index = bar_index
        self._setup_active = True

    def _reset_setup(self):
        self._setup_active = False

    def _execute_trade(self, trade_type, sl_base, tp_base):
        if self._trading_halted:
            return
        entry = self.Symbol.Ask if trade_type == TradeType.Buy else self.Symbol.Bid
        pip = self.Symbol.PipSize
        atr_val = self._atr.Result[min(len(self.Bars) - 2, len(self._atr.Result) - 1)]

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
            sl_dist = orig_sl * max(0.01, self.SLMultiplier)
            tp_dist = orig_tp * max(0.01, self.TPMultiplier)
            sl = entry - sl_dist if trade_type == TradeType.Buy else entry + sl_dist
            tp = entry + tp_dist if trade_type == TradeType.Buy else entry - tp_dist
        elif mode == 3:
            if self.CustomSL > 0:
                sl = entry - self.CustomSL * pip if trade_type == TradeType.Buy else entry + self.CustomSL * pip
            if self.CustomTP > 0:
                tp = entry + self.CustomTP * pip if trade_type == TradeType.Buy else entry - self.CustomTP * pip

        sl = round(sl, self.Symbol.Digits)
        tp = round(tp, self.Symbol.Digits)
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

        result = self.ExecuteMarketOrder(trade_type, self.SymbolName, volume, self.TradeLabel)
        if result is None or not result.IsSuccessful or result.Position is None:
            return
        self.ModifyPosition(result.Position, sl, tp)

    def _ml_allow(self, i, atr_val, ema_fast_val, ema_slow_val, high, low):
        if self._ml_model is None:
            return True if self.MlFailOpen else False
        try:
            impulse = high - low
            atr_prev = self._atr.Result[max(0, i - 10)]
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

    def _is_bullish_impulse(self, i, atr_val):
        return self.Bars.ClosePrices[i] > self.Bars.OpenPrices[i] and (self.Bars.ClosePrices[i] - self.Bars.OpenPrices[i]) > atr_val * 0.4

    def _is_bearish_impulse(self, i, atr_val):
        return self.Bars.ClosePrices[i] < self.Bars.OpenPrices[i] and (self.Bars.OpenPrices[i] - self.Bars.ClosePrices[i]) > atr_val * 0.4

    def _is_london_or_ny(self):
        h = self.Server.Time.Hour
        return 7 <= h <= 21
