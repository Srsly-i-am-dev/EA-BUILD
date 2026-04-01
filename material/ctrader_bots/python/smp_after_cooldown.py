from ctrader.algo.api import *


class SMPAfterCooldown(cBot):
    EmaFast = Parameter(default=50, description="EMA Fast")
    EmaSlow = Parameter(default=200, description="EMA Slow")
    AtrPeriod = Parameter(default=14, description="ATR Period")
    SwingLookback = Parameter(default=15, description="Swing Lookback")
    MinImpulseATR = Parameter(default=0.8, description="Min Impulse ATR")
    RiskPercent = Parameter(default=0.5, description="Risk %")
    MaxLots = Parameter(default=0.5, description="Max Lots")
    CustomSL = Parameter(default=0.0, description="Custom SL pips (0=off)")
    CustomTP = Parameter(default=0.0, description="Custom TP pips (0=off)")
    CooldownBars = Parameter(default=6, description="Cooldown bars after trade close")
    RequireNewSwing = Parameter(default=True, description="Require new swing after cooldown")

    UseMlFilter = Parameter(default=True, description="Enable XGBoost ML signal filter")
    MlModelPath = Parameter(default="xgboost_model.joblib", description="Path to trained .joblib model")
    MlMinProb = Parameter(default=0.55, description="Min ML probability to allow setup")
    MlFailOpen = Parameter(default=True, description="If True, allow setup when ML errors")
    ScaleRiskByMl = Parameter(default=False, description="Scale risk by ML confidence")
    MlMaxScale = Parameter(default=1.5, description="Max risk scale when ML confidence is high")

    BOT_LABEL = "SMP_COOLDOWN"

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

        self._in_cooldown = False
        self._cooldown_start_idx = 0
        self._new_swing_detected = True
        self._last_swing_high = float("-inf")
        self._last_swing_low = float("inf")

        self._ml_model = None
        self._last_ml_prob = 0.5
        if self.UseMlFilter:
            try:
                import joblib
                self._ml_model = joblib.load(self.MlModelPath)
                self.Print(f"[SMPAfterCooldown] ML model loaded from {self.MlModelPath}")
            except Exception as e:
                self.Print(f"[SMPAfterCooldown] ML load failed: {e}")

        self.Positions.Closed += self._on_position_closed

    def on_bar(self):
        i = len(self.Bars) - 2
        if i < self.SwingLookback + 5:
            return
        if not self._is_london_or_ny():
            return
        if self.Positions.Find(self.BOT_LABEL, self.SymbolName) is not None:
            return
        if self._setup_active:
            return

        if self._in_cooldown:
            if i - self._cooldown_start_idx < self.CooldownBars:
                return
            if self.RequireNewSwing and not self._new_swing_detected:
                self._detect_new_swing(i)
                if not self._new_swing_detected:
                    return
            self._in_cooldown = False

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
        if not self._setup_active:
            return
        if self.Positions.Find(self.BOT_LABEL, self.SymbolName) is not None:
            return
        if len(self.Bars) - 2 > self._setup_bar_index + 3:
            self._reset_setup()
            return
        trigger = self.Symbol.Ask if self._setup_type == TradeType.Buy else self.Symbol.Bid
        if self._fib_low <= trigger <= self._fib_high:
            self._execute_trade(self._setup_type, self._sl, self._tp)
            self._reset_setup()

    def _on_position_closed(self, args):
        pos = args.Position
        if pos is None:
            return
        if pos.SymbolName != self.SymbolName:
            return
        if pos.Label != self.BOT_LABEL:
            return
        self._in_cooldown = True
        self._cooldown_start_idx = len(self.Bars) - 2
        self._new_swing_detected = False

        i = len(self.Bars) - 2
        start = max(0, i - self.SwingLookback)
        self._last_swing_high = max(self.Bars.HighPrices[x] for x in range(start, i + 1))
        self._last_swing_low = min(self.Bars.LowPrices[x] for x in range(start, i + 1))

    def _detect_new_swing(self, i):
        start = max(0, i - self.SwingLookback)
        current_high = max(self.Bars.HighPrices[x] for x in range(start, i + 1))
        current_low = min(self.Bars.LowPrices[x] for x in range(start, i + 1))
        threshold = self._atr.Result[i] * 0.3
        if current_high > self._last_swing_high + threshold or current_low < self._last_swing_low - threshold:
            self._new_swing_detected = True

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
        entry = self.Symbol.Ask if trade_type == TradeType.Buy else self.Symbol.Bid
        final_sl = sl_base
        final_tp = tp_base
        if self.CustomSL > 0:
            final_sl = entry - self.CustomSL * self.Symbol.PipSize if trade_type == TradeType.Buy else entry + self.CustomSL * self.Symbol.PipSize
        if self.CustomTP > 0:
            final_tp = entry + self.CustomTP * self.Symbol.PipSize if trade_type == TradeType.Buy else entry - self.CustomTP * self.Symbol.PipSize

        risk_pips = abs(entry - final_sl) / self.Symbol.PipSize
        if risk_pips < 5:
            return

        risk_scale = self._risk_scale_from_ml()
        risk_money = self.Account.Balance * ((self.RiskPercent * risk_scale) / 100.0)
        volume = risk_money / (risk_pips * self.Symbol.PipValue)
        volume = min(volume, self.Symbol.QuantityToVolumeInUnits(self.MaxLots))
        volume = self.Symbol.NormalizeVolumeInUnits(volume)
        if volume <= 0:
            return
        result = self.ExecuteMarketOrder(trade_type, self.SymbolName, volume, self.BOT_LABEL)
        if result is None or not result.IsSuccessful or result.Position is None:
            return
        self.ModifyPosition(result.Position, final_sl, final_tp)

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
