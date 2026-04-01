"""
Python-based backtest simulator for GoldBB & GoldPattern EAs.
Uses MT5 Python API for historical data, simulates signal logic in Python.

This avoids the unreliable MT5 CLI /config: approach and gives us full control
over the optimization loop.

Usage:
    python backtest_sim.py --ea GoldBB --symbol XAUUSD --tf M5 --from 2024.01.01 --to 2025.01.01
    python backtest_sim.py --ea GoldPattern --symbol XAUUSD --tf M5 --from 2024.06.01 --to 2025.01.01
    python backtest_sim.py --ea GoldBB --symbol XAUUSD --tf M5 --sweep   # parameter sweep
"""

import MetaTrader5 as mt5
import numpy as np
import json
import math
import argparse
import sys
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, field, asdict

EA_BUILD_DIR = Path(r"C:\Users\DEV\OneDrive\Desktop\EA BUILD")
RESULTS_DIR = EA_BUILD_DIR / "optimizer" / "results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

TF_MAP = {"M1": mt5.TIMEFRAME_M1, "M5": mt5.TIMEFRAME_M5, "M15": mt5.TIMEFRAME_M15}


# ─────────────────────────────────────────────────────────
# Indicator calculations (pure numpy)
# ─────────────────────────────────────────────────────────

def calc_sma(data, period):
    """Simple moving average."""
    out = np.full_like(data, np.nan)
    if len(data) < period:
        return out
    cumsum = np.cumsum(data)
    out[period-1:] = (cumsum[period-1:] - np.concatenate([[0], cumsum[:-period]])) / period
    return out


def calc_ema(data, period):
    """Exponential moving average."""
    out = np.full_like(data, np.nan, dtype=float)
    if len(data) < period:
        return out
    k = 2.0 / (period + 1)
    out[period-1] = np.mean(data[:period])
    for i in range(period, len(data)):
        out[i] = data[i] * k + out[i-1] * (1 - k)
    return out


def calc_rsi(close, period=14):
    """RSI calculation."""
    out = np.full(len(close), 50.0)
    if len(close) < period + 1:
        return out
    delta = np.diff(close)
    gain = np.where(delta > 0, delta, 0.0)
    loss = np.where(delta < 0, -delta, 0.0)

    avg_gain = np.mean(gain[:period])
    avg_loss = np.mean(loss[:period])

    for i in range(period, len(delta)):
        avg_gain = (avg_gain * (period - 1) + gain[i]) / period
        avg_loss = (avg_loss * (period - 1) + loss[i]) / period
        if avg_loss == 0:
            out[i+1] = 100.0
        else:
            rs = avg_gain / avg_loss
            out[i+1] = 100.0 - (100.0 / (1.0 + rs))
    return out


def calc_atr(high, low, close, period=14):
    """ATR calculation."""
    n = len(close)
    tr = np.zeros(n)
    tr[0] = high[0] - low[0]
    for i in range(1, n):
        tr[i] = max(high[i] - low[i], abs(high[i] - close[i-1]), abs(low[i] - close[i-1]))

    atr = np.full(n, np.nan)
    if n < period:
        return atr
    atr[period-1] = np.mean(tr[:period])
    for i in range(period, n):
        atr[i] = (atr[i-1] * (period - 1) + tr[i]) / period
    return atr


def calc_bb(close, ma_period=20, std_period=21, dev=2.0):
    """Bollinger Bands (MA + StdDev)."""
    ma = calc_sma(close, ma_period)
    std = np.full(len(close), np.nan)
    for i in range(std_period - 1, len(close)):
        std[i] = np.std(close[i-std_period+1:i+1], ddof=0)
    upper = ma + dev * std
    lower = ma - dev * std
    return ma, upper, lower, std


def calc_supertrend(high, low, close, atr_period=7, mult=2.0):
    """SuperTrend indicator."""
    n = len(close)
    atr = calc_atr(high, low, close, atr_period)
    direction = np.zeros(n, dtype=int)  # 1=buy, 2=sell
    st_line = np.zeros(n)

    upper_band = np.zeros(n)
    lower_band = np.zeros(n)

    start = atr_period
    for i in range(start, n):
        hl2 = (high[i] + low[i]) / 2.0
        ub = hl2 + mult * atr[i]
        lb = hl2 - mult * atr[i]

        # Band clamping
        if i > start:
            if ub < upper_band[i-1] or close[i-1] > upper_band[i-1]:
                upper_band[i] = ub
            else:
                upper_band[i] = upper_band[i-1]

            if lb > lower_band[i-1] or close[i-1] < lower_band[i-1]:
                lower_band[i] = lb
            else:
                lower_band[i] = lower_band[i-1]
        else:
            upper_band[i] = ub
            lower_band[i] = lb

        # Direction
        if i > start:
            if direction[i-1] == 1:  # was buy
                if close[i] < lower_band[i]:
                    direction[i] = 2  # flip to sell
                    st_line[i] = upper_band[i]
                else:
                    direction[i] = 1
                    st_line[i] = lower_band[i]
            else:  # was sell
                if close[i] > upper_band[i]:
                    direction[i] = 1  # flip to buy
                    st_line[i] = lower_band[i]
                else:
                    direction[i] = 2
                    st_line[i] = upper_band[i]
        else:
            direction[i] = 1 if close[i] > upper_band[i] else 2
            st_line[i] = lower_band[i] if direction[i] == 1 else upper_band[i]

    return direction, st_line


def calc_zlema(close, length=70, atr=None, band_mult=1.5):
    """Zero-Lag EMA with volatility bands."""
    n = len(close)
    lag = (length - 1) // 2
    src_corrected = np.zeros(n)
    for i in range(lag, n):
        src_corrected[i] = close[i] + (close[i] - close[i - lag])

    zlema = calc_ema(src_corrected, length)
    direction = np.zeros(n, dtype=int)  # 1=buy, 2=sell, 0=none

    if atr is not None:
        for i in range(length * 2, n):
            if np.isnan(zlema[i]) or np.isnan(atr[i]):
                continue
            vol_band = atr[i] * band_mult
            if close[i] > zlema[i] + vol_band:
                direction[i] = 1
            elif close[i] < zlema[i] - vol_band:
                direction[i] = 2
            else:
                direction[i] = direction[i-1] if i > 0 else 0
    return zlema, direction


def calc_vwap(high, low, close, tick_volume, times):
    """Session VWAP (resets daily)."""
    n = len(close)
    vwap = np.zeros(n)
    cum_pv = 0.0
    cum_vol = 0.0
    last_day = -1

    for i in range(n):
        dt = datetime.utcfromtimestamp(times[i])
        day = dt.day
        if day != last_day:
            cum_pv = 0.0
            cum_vol = 0.0
            last_day = day

        tp = (high[i] + low[i] + close[i]) / 3.0
        cum_pv += tp * tick_volume[i]
        cum_vol += tick_volume[i]
        vwap[i] = cum_pv / cum_vol if cum_vol > 0 else tp

    return vwap


def calc_stddev_regime(close, period=20, sma_period=50):
    """StdDev regime: current StdDev vs SMA of StdDev."""
    n = len(close)
    stddev = np.full(n, np.nan)
    for i in range(period - 1, n):
        stddev[i] = np.std(close[i-period+1:i+1], ddof=0)

    stddev_sma = calc_sma(stddev, sma_period)
    ratio = np.where(stddev_sma > 0, stddev / stddev_sma, 1.0)
    # Safe for mean-reversion if ratio < 1.5 (not extreme vol)
    is_safe = ratio < 1.5
    return stddev, ratio, is_safe


def calc_keltner(close, high, low, ema_period=20, atr_period=10, mult=2.0):
    """Keltner Channel."""
    ema_mid = calc_ema(close, ema_period)
    atr = calc_atr(high, low, close, atr_period)
    kc_upper = ema_mid + mult * atr
    kc_lower = ema_mid - mult * atr
    return ema_mid, kc_upper, kc_lower


def cosine_similarity(a, b):
    """Cosine similarity between two vectors."""
    dot = np.dot(a, b)
    na = np.linalg.norm(a)
    nb = np.linalg.norm(b)
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


# ─────────────────────────────────────────────────────────
# GoldBB Strategy Simulation
# ─────────────────────────────────────────────────────────

@dataclass
class BBParams:
    bb_period: int = 20
    bb_dev: float = 2.0
    bb_std_period: int = 21
    close_back_inside: bool = True
    touch_buffer: float = 10.0  # points
    st_atr: int = 7
    st_mult: float = 2.0
    st_enable: bool = True
    kc_enable: bool = True
    kc_ema: int = 20
    kc_atr: int = 10
    kc_mult: float = 2.0
    zl_enable: bool = True
    zl_length: int = 70
    zl_band: float = 1.5
    vwap_enable: bool = True
    stddev_enable: bool = True
    stddev_period: int = 20
    stddev_sma: int = 50
    rsi_enable: bool = True
    rsi_period: int = 10
    rsi_dev: float = 20.0
    vol_enable: bool = True
    vol_mult: float = 1.2
    vol_window: int = 10
    atr_period: int = 14
    atr_min_gate: float = 0.30
    tp_atr: float = 0.75
    sl_atr: float = 1.50
    tp_spread: float = 8.0
    sl_spread: float = 6.0
    min_tp: float = 30.0  # points
    max_tp: float = 200.0
    min_sl: float = 40.0
    max_sl: float = 250.0
    min_rr: float = 0.4
    score_threshold: int = 65
    session_start: int = 7
    session_end: int = 21
    max_spread: int = 40
    base_lots: float = 0.10
    point: float = 0.01  # XAUUSD


@dataclass
class PatternParams:
    pattern_candles: int = 5
    similarity: float = 0.80
    min_matches: int = 10
    min_accuracy: float = 60.0
    lookback: int = 5000
    future_bars: int = 10
    use_wicks: bool = True
    st_atr: int = 7
    st_mult: float = 2.0
    st_enable: bool = True
    zl_enable: bool = True
    zl_length: int = 70
    zl_band: float = 1.5
    vwap_enable: bool = True
    stddev_enable: bool = True
    stddev_period: int = 20
    stddev_sma: int = 50
    rsi_enable: bool = True
    rsi_period: int = 10
    rsi_dev: float = 20.0
    vol_enable: bool = True
    vol_mult: float = 1.2
    vol_window: int = 10
    atr_period: int = 14
    atr_min_gate: float = 0.30
    tp_atr: float = 0.75
    sl_atr: float = 1.50
    min_tp: float = 30.0
    max_tp: float = 200.0
    min_sl: float = 40.0
    max_sl: float = 250.0
    min_rr: float = 0.4
    score_threshold: int = 65
    session_start: int = 7
    session_end: int = 21
    max_spread: int = 40
    base_lots: float = 0.10
    point: float = 0.01


@dataclass
class Trade:
    entry_bar: int = 0
    entry_price: float = 0.0
    direction: int = 0  # 1=buy, 2=sell
    tp: float = 0.0
    sl: float = 0.0
    exit_bar: int = 0
    exit_price: float = 0.0
    profit: float = 0.0
    score: int = 0
    lots: float = 0.10
    comment: str = ""


def calc_score_bb(primary_ok, st_ok, kc_ok, sd_ok, zl_ok, vw_ok, rsi_ok, vol_ok):
    """Weighted scoring for GoldBB."""
    if not primary_ok:
        return 0
    score = 30  # BB primary
    if st_ok:  score += 20
    if kc_ok:  score += 15
    if sd_ok:  score += 10
    if zl_ok:  score += 10
    if vw_ok:  score += 5
    if rsi_ok: score += 5
    if vol_ok: score += 5
    return score


def calc_score_pattern(primary_ok, st_ok, zl_ok, vw_ok, sd_ok, rsi_ok, vol_ok):
    """Weighted scoring for GoldPattern."""
    if not primary_ok:
        return 0
    score = 30
    if st_ok:  score += 20
    if zl_ok:  score += 15
    if vw_ok:  score += 10
    if sd_ok:  score += 10
    if rsi_ok: score += 10
    if vol_ok: score += 5
    return score


def get_lot_factor(score):
    if score >= 85: return 1.0
    if score >= 75: return 0.75
    return 0.50


def run_goldbb_backtest(rates, params: BBParams, spread_points=15):
    """Simulate GoldBB strategy on historical data."""
    n = len(rates)
    open_p = rates['open'].astype(float)
    high = rates['high'].astype(float)
    low = rates['low'].astype(float)
    close = rates['close'].astype(float)
    tick_vol = rates['tick_volume'].astype(float)
    times = rates['time'].astype(int)
    spreads = rates['spread'].astype(float)

    # Pre-calculate all indicators
    bb_ma, bb_upper, bb_lower, bb_std = calc_bb(close, params.bb_period, params.bb_std_period, params.bb_dev)
    atr = calc_atr(high, low, close, params.atr_period)
    rsi = calc_rsi(close, params.rsi_period)

    st_dir, st_line = (calc_supertrend(high, low, close, params.st_atr, params.st_mult)
                       if params.st_enable else (np.ones(n, dtype=int), np.zeros(n)))

    zlema, zl_dir = (calc_zlema(close, params.zl_length, atr, params.zl_band)
                     if params.zl_enable else (np.zeros(n), np.zeros(n, dtype=int)))

    vwap = calc_vwap(high, low, close, tick_vol, times) if params.vwap_enable else np.zeros(n)

    _, sd_ratio, sd_safe = (calc_stddev_regime(close, params.stddev_period, params.stddev_sma)
                            if params.stddev_enable else (np.zeros(n), np.ones(n), np.ones(n, dtype=bool)))

    kc_mid, kc_upper, kc_lower = (calc_keltner(close, high, low, params.kc_ema, params.kc_atr, params.kc_mult)
                                   if params.kc_enable else (np.zeros(n), np.zeros(n), np.zeros(n)))

    trades = []
    in_trade = False
    current_trade = None
    warmup = max(200, params.bb_period + params.bb_std_period, params.zl_length * 2 if params.zl_enable else 0)

    for i in range(warmup, n):
        # Session filter
        dt = datetime.utcfromtimestamp(times[i])
        hour = dt.hour
        if hour < params.session_start or hour >= params.session_end:
            if in_trade:
                # Manage open trade
                current_trade = _check_tp_sl(current_trade, i, high, low, close, params.point)
                if current_trade.exit_bar > 0:
                    trades.append(current_trade)
                    in_trade = False
            continue

        # Manage open trade
        if in_trade:
            current_trade = _check_tp_sl(current_trade, i, high, low, close, params.point)
            if current_trade.exit_bar > 0:
                trades.append(current_trade)
                in_trade = False
            continue

        # Spread filter
        spread = spreads[i] if spreads[i] > 0 else spread_points
        if spread > params.max_spread:
            continue

        # ATR gate
        if np.isnan(atr[i]) or atr[i] < params.atr_min_gate:
            continue

        # === PRIMARY: BB signal ===
        signal = 0  # 0=none, 1=buy, 2=sell
        if not np.isnan(bb_lower[i]) and not np.isnan(bb_upper[i]):
            buf = params.touch_buffer * params.point
            if params.close_back_inside:
                # Close-back-inside: prev bar closed below lower BB, current closes above
                if i > 0 and close[i-1] < bb_lower[i-1] and close[i] > bb_lower[i]:
                    signal = 1
                elif i > 0 and close[i-1] > bb_upper[i-1] and close[i] < bb_upper[i]:
                    signal = 2
            else:
                # Touch mode
                if low[i] <= bb_lower[i] + buf:
                    signal = 1
                elif high[i] >= bb_upper[i] - buf:
                    signal = 2

        if signal == 0:
            continue

        primary_ok = True

        # BB squeeze check (BB inside KC)
        kc_ok = True
        if params.kc_enable and not np.isnan(kc_upper[i]) and not np.isnan(bb_upper[i]):
            squeeze = bb_upper[i] < kc_upper[i] and bb_lower[i] > kc_lower[i]
            kc_ok = not squeeze  # NOT in squeeze is good

        # SuperTrend agrees
        st_ok = True if not params.st_enable else (st_dir[i] == signal)

        # ZLEMA agrees
        zl_ok = True if not params.zl_enable else (zl_dir[i] == signal or zl_dir[i] == 0)

        # VWAP bias
        vw_ok = True
        if params.vwap_enable and vwap[i] > 0:
            if signal == 1:
                vw_ok = close[i] < vwap[i]  # buy below VWAP
            else:
                vw_ok = close[i] > vwap[i]  # sell above VWAP

        # StdDev regime
        sd_ok = True if not params.stddev_enable else bool(sd_safe[i])

        # RSI
        rsi_ok = True
        if params.rsi_enable and i > 0:
            rsi_val = rsi[i]
            rsi_prev = rsi[i-1]
            if signal == 1:
                rsi_ok = (rsi_prev < 50 - params.rsi_dev and rsi_val > 50 - params.rsi_dev) or (rsi_val < rsi_prev + 5)
                rsi_ok = rsi_val < 50 + params.rsi_dev  # not overbought
            else:
                rsi_ok = (rsi_prev > 50 + params.rsi_dev and rsi_val < 50 + params.rsi_dev) or (rsi_val > rsi_prev - 5)
                rsi_ok = rsi_val > 50 - params.rsi_dev  # not oversold

        # Volume
        vol_ok = True
        if params.vol_enable and i >= params.vol_window:
            avg_vol = np.mean(tick_vol[i-params.vol_window:i])
            vol_ok = tick_vol[i] >= avg_vol * params.vol_mult if avg_vol > 0 else True

        # Score
        score = calc_score_bb(primary_ok, st_ok, kc_ok, sd_ok, zl_ok, vw_ok, rsi_ok, vol_ok)
        if score < params.score_threshold:
            continue

        # TP/SL
        spread_price = spread * params.point
        tp_dist = max(atr[i] * params.tp_atr, spread_price * params.tp_spread)
        sl_dist = max(atr[i] * params.sl_atr, spread_price * params.sl_spread)

        tp_dist = max(params.min_tp * params.point, min(params.max_tp * params.point, tp_dist))
        sl_dist = max(params.min_sl * params.point, min(params.max_sl * params.point, sl_dist))

        if sl_dist > 0 and tp_dist / sl_dist < params.min_rr:
            continue

        entry = close[i] + (spread_price / 2 if signal == 1 else -spread_price / 2)
        tp_price = entry + tp_dist if signal == 1 else entry - tp_dist
        sl_price = entry - sl_dist if signal == 1 else entry + sl_dist

        lots = params.base_lots * get_lot_factor(score)

        current_trade = Trade(
            entry_bar=i, entry_price=entry, direction=signal,
            tp=tp_price, sl=sl_price, score=score, lots=lots,
            comment=f"BB_S{score}"
        )
        in_trade = True

    # Close any open trade at end
    if in_trade and current_trade.exit_bar == 0:
        current_trade.exit_bar = n - 1
        current_trade.exit_price = close[n-1]
        pips = (current_trade.exit_price - current_trade.entry_price) if current_trade.direction == 1 \
               else (current_trade.entry_price - current_trade.exit_price)
        current_trade.profit = pips / params.point * current_trade.lots
        trades.append(current_trade)

    return trades


def _check_tp_sl(trade, bar_idx, high, low, close, point):
    """Check if TP or SL is hit on this bar."""
    if trade.direction == 1:  # buy
        if low[bar_idx] <= trade.sl:
            trade.exit_bar = bar_idx
            trade.exit_price = trade.sl
            trade.profit = (trade.sl - trade.entry_price) / point * trade.lots
            return trade
        if high[bar_idx] >= trade.tp:
            trade.exit_bar = bar_idx
            trade.exit_price = trade.tp
            trade.profit = (trade.tp - trade.entry_price) / point * trade.lots
            return trade
    else:  # sell
        if high[bar_idx] >= trade.sl:
            trade.exit_bar = bar_idx
            trade.exit_price = trade.sl
            trade.profit = (trade.entry_price - trade.sl) / point * trade.lots
            return trade
        if low[bar_idx] <= trade.tp:
            trade.exit_bar = bar_idx
            trade.exit_price = trade.tp
            trade.profit = (trade.entry_price - trade.tp) / point * trade.lots
            return trade
    return trade


# ─────────────────────────────────────────────────────────
# GoldPattern Strategy Simulation
# ─────────────────────────────────────────────────────────

def build_pattern_vector(open_p, high, low, close, idx, length, use_wicks=True):
    """Build 4D pattern vector like the MQL5 PatternMatcher."""
    if idx < length:
        return None
    vec = []
    for j in range(idx - length, idx):
        bar_range = high[j] - low[j]
        if bar_range == 0:
            bar_range = 0.0001
        body = (close[j] - open_p[j]) / bar_range
        if use_wicks:
            upper_wick = (high[j] - max(open_p[j], close[j])) / bar_range
            lower_wick = (min(open_p[j], close[j]) - low[j]) / bar_range
            vec.extend([body, 1.0, upper_wick, lower_wick])
        else:
            vec.extend([body, 1.0])
    return np.array(vec, dtype=float)


def scan_pattern(open_p, high, low, close, idx, params: PatternParams):
    """Scan history for similar patterns and compute bias."""
    current_vec = build_pattern_vector(open_p, high, low, close, idx, params.pattern_candles, params.use_wicks)
    if current_vec is None:
        return 0, 0, 0.0  # no signal

    lookback_start = max(params.pattern_candles + params.future_bars, idx - params.lookback)
    matches_up = 0
    matches_down = 0
    total_matches = 0

    for k in range(lookback_start, idx - params.future_bars - params.pattern_candles):
        hist_vec = build_pattern_vector(open_p, high, low, close, k, params.pattern_candles, params.use_wicks)
        if hist_vec is None:
            continue
        sim = cosine_similarity(current_vec, hist_vec)
        if sim >= params.similarity:
            total_matches += 1
            # Check what happened after this pattern
            future_close = close[k + params.future_bars]
            pattern_close = close[k]
            if future_close > pattern_close:
                matches_up += 1
            else:
                matches_down += 1

            if total_matches >= 100:  # cap matches
                break

    if total_matches < params.min_matches:
        return 0, total_matches, 0.0

    up_acc = matches_up / total_matches * 100 if total_matches > 0 else 0
    down_acc = matches_down / total_matches * 100 if total_matches > 0 else 0
    confidence = max(up_acc, down_acc)

    if confidence < params.min_accuracy:
        return 0, total_matches, confidence

    if up_acc > down_acc:
        return 1, total_matches, confidence  # buy
    elif down_acc > up_acc:
        return 2, total_matches, confidence  # sell
    return 0, total_matches, confidence


def run_goldpattern_backtest(rates, params: PatternParams, spread_points=15):
    """Simulate GoldPattern strategy on historical data."""
    n = len(rates)
    open_p = rates['open'].astype(float)
    high = rates['high'].astype(float)
    low = rates['low'].astype(float)
    close = rates['close'].astype(float)
    tick_vol = rates['tick_volume'].astype(float)
    times = rates['time'].astype(int)
    spreads = rates['spread'].astype(float)

    # Pre-calc indicators
    atr = calc_atr(high, low, close, params.atr_period)
    rsi = calc_rsi(close, params.rsi_period)

    st_dir, st_line = (calc_supertrend(high, low, close, params.st_atr, params.st_mult)
                       if params.st_enable else (np.ones(n, dtype=int), np.zeros(n)))

    zlema, zl_dir = (calc_zlema(close, params.zl_length, atr, params.zl_band)
                     if params.zl_enable else (np.zeros(n), np.zeros(n, dtype=int)))

    vwap = calc_vwap(high, low, close, tick_vol, times) if params.vwap_enable else np.zeros(n)

    _, sd_ratio, sd_safe = (calc_stddev_regime(close, params.stddev_period, params.stddev_sma)
                            if params.stddev_enable else (np.zeros(n), np.ones(n), np.ones(n, dtype=bool)))

    trades = []
    in_trade = False
    current_trade = None
    # Need enough bars for lookback
    warmup = max(500, params.lookback // 2)

    print(f"  Pattern scan: {n - warmup} bars to process (this is slow)...")

    for i in range(warmup, n):
        if i % 2000 == 0:
            print(f"  Progress: {i}/{n} ({i*100//n}%)")

        dt = datetime.utcfromtimestamp(times[i])
        hour = dt.hour
        if hour < params.session_start or hour >= params.session_end:
            if in_trade:
                current_trade = _check_tp_sl(current_trade, i, high, low, close, params.point)
                if current_trade.exit_bar > 0:
                    trades.append(current_trade)
                    in_trade = False
            continue

        if in_trade:
            current_trade = _check_tp_sl(current_trade, i, high, low, close, params.point)
            if current_trade.exit_bar > 0:
                trades.append(current_trade)
                in_trade = False
            continue

        spread = spreads[i] if spreads[i] > 0 else spread_points
        if spread > params.max_spread:
            continue

        if np.isnan(atr[i]) or atr[i] < params.atr_min_gate:
            continue

        # PRIMARY: Pattern scan (expensive)
        signal, total_matches, confidence = scan_pattern(open_p, high, low, close, i, params)
        if signal == 0:
            continue

        primary_ok = True
        st_ok = True if not params.st_enable else (st_dir[i] == signal)
        zl_ok = True if not params.zl_enable else (zl_dir[i] == signal or zl_dir[i] == 0)

        vw_ok = True
        if params.vwap_enable and vwap[i] > 0:
            vw_ok = (close[i] > vwap[i]) if signal == 1 else (close[i] < vwap[i])

        sd_ok = True if not params.stddev_enable else bool(sd_safe[i])

        rsi_ok = True
        if params.rsi_enable and i > 0:
            if signal == 1:
                rsi_ok = rsi[i] > rsi[i-1]
            else:
                rsi_ok = rsi[i] < rsi[i-1]

        vol_ok = True
        if params.vol_enable and i >= params.vol_window:
            avg_vol = np.mean(tick_vol[i-params.vol_window:i])
            vol_ok = tick_vol[i] >= avg_vol * params.vol_mult if avg_vol > 0 else True

        score = calc_score_pattern(primary_ok, st_ok, zl_ok, vw_ok, sd_ok, rsi_ok, vol_ok)
        if score < params.score_threshold:
            continue

        spread_price = spread * params.point
        tp_dist = atr[i] * params.tp_atr
        sl_dist = atr[i] * params.sl_atr
        tp_dist = max(params.min_tp * params.point, min(params.max_tp * params.point, tp_dist))
        sl_dist = max(params.min_sl * params.point, min(params.max_sl * params.point, sl_dist))

        if sl_dist > 0 and tp_dist / sl_dist < params.min_rr:
            continue

        entry = close[i] + (spread_price / 2 if signal == 1 else -spread_price / 2)
        tp_price = entry + tp_dist if signal == 1 else entry - tp_dist
        sl_price = entry - sl_dist if signal == 1 else entry + sl_dist

        lots = params.base_lots * get_lot_factor(score)

        current_trade = Trade(
            entry_bar=i, entry_price=entry, direction=signal,
            tp=tp_price, sl=sl_price, score=score, lots=lots,
            comment=f"PAT_S{score}_M{total_matches}_C{confidence:.0f}"
        )
        in_trade = True

    if in_trade and current_trade.exit_bar == 0:
        current_trade.exit_bar = n - 1
        current_trade.exit_price = close[n-1]
        pips = (current_trade.exit_price - current_trade.entry_price) if current_trade.direction == 1 \
               else (current_trade.entry_price - current_trade.exit_price)
        current_trade.profit = pips / params.point * current_trade.lots
        trades.append(current_trade)

    return trades


# ─────────────────────────────────────────────────────────
# Performance Metrics
# ─────────────────────────────────────────────────────────

def analyze_trades(trades, deposit=10000):
    """Calculate comprehensive performance metrics."""
    if not trades:
        return {"total_trades": 0, "profit_factor": 0, "win_rate": 0,
                "total_profit": 0, "max_drawdown": 0, "sharpe": 0}

    profits = [t.profit for t in trades]
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]

    gross_profit = sum(wins)
    gross_loss = abs(sum(losses))

    equity = 0.0
    peak = 0.0
    max_dd = 0.0
    for p in profits:
        equity += p
        peak = max(peak, equity)
        dd = peak - equity
        max_dd = max(max_dd, dd)

    total = len(profits)
    avg = sum(profits) / total
    var = sum((p - avg) ** 2 for p in profits) / total if total > 1 else 0
    std = math.sqrt(var) if var > 0 else 1
    sharpe = (avg / std) * math.sqrt(252) if std > 0 else 0

    scores = [t.score for t in trades]

    return {
        "total_trades": total,
        "wins": len(wins),
        "losses": len(losses),
        "win_rate": round(len(wins) / total * 100, 1),
        "profit_factor": round(gross_profit / gross_loss, 2) if gross_loss > 0 else 999.0,
        "total_profit": round(sum(profits), 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "avg_win": round(sum(wins) / len(wins), 2) if wins else 0,
        "avg_loss": round(sum(losses) / len(losses), 2) if losses else 0,
        "max_drawdown": round(max_dd, 2),
        "max_dd_pct": round(max_dd / deposit * 100, 1),
        "sharpe": round(sharpe, 2),
        "expectancy": round(avg, 2),
        "avg_score": round(sum(scores) / len(scores), 1) if scores else 0,
        "return_pct": round(sum(profits) / deposit * 100, 1),
    }


# ─────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────

def fetch_data(symbol, tf_str, date_from, date_to):
    """Fetch historical data from MT5."""
    tf = TF_MAP.get(tf_str, mt5.TIMEFRAME_M5)
    from_dt = datetime.strptime(date_from, "%Y.%m.%d")
    to_dt = datetime.strptime(date_to, "%Y.%m.%d")

    rates = mt5.copy_rates_range(symbol, tf, from_dt, to_dt)
    if rates is None or len(rates) == 0:
        print(f"No data for {symbol} {tf_str} from {date_from} to {date_to}")
        return None
    print(f"Fetched {len(rates)} bars for {symbol} {tf_str} ({date_from} to {date_to})")
    return rates


def log_iteration(ea, symbol, tf, params_dict, results, notes):
    """Append to iteration log."""
    log_path = RESULTS_DIR / "iteration_log.json"
    if log_path.exists():
        data = json.loads(log_path.read_text(encoding="utf-8"))
    else:
        data = {"iterations": []}

    it_id = len(data["iterations"]) + 1
    data["iterations"].append({
        "id": it_id,
        "timestamp": datetime.now().isoformat(),
        "ea": ea,
        "symbol": symbol,
        "tf": tf,
        "params": params_dict,
        "results": results,
        "notes": notes,
    })
    log_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return it_id


def main():
    parser = argparse.ArgumentParser(description="Python Backtest Simulator for GoldBB/GoldPattern")
    parser.add_argument("--ea", choices=["GoldBB", "GoldPattern"], default="GoldBB")
    parser.add_argument("--symbol", default="XAUUSD")
    parser.add_argument("--tf", choices=["M1", "M5", "M15"], default="M5")
    parser.add_argument("--from-date", dest="date_from", default="2024.01.01")
    parser.add_argument("--to-date", dest="date_to", default="2025.01.01")
    parser.add_argument("--sweep", action="store_true", help="Run parameter sweep")
    parser.add_argument("--deposit", type=float, default=10000)

    args = parser.parse_args()

    if not mt5.initialize():
        print(f"MT5 init failed: {mt5.last_error()}")
        sys.exit(1)

    try:
        # Get symbol info for point value
        sym_info = mt5.symbol_info(args.symbol)
        if sym_info is None:
            print(f"Symbol {args.symbol} not found")
            sys.exit(1)
        point = sym_info.point
        avg_spread = sym_info.spread

        rates = fetch_data(args.symbol, args.tf, args.date_from, args.date_to)
        if rates is None:
            sys.exit(1)

        if args.ea == "GoldBB":
            params = BBParams(point=point)
            print(f"\n=== GoldBB Backtest: {args.symbol} {args.tf} ===")
            print(f"  BB({params.bb_period}, {params.bb_dev}) | ST({params.st_atr}, {params.st_mult})")
            print(f"  TP={params.tp_atr}xATR SL={params.sl_atr}xATR | Score>={params.score_threshold}")

            if args.sweep:
                run_bb_sweep(rates, point, args, avg_spread)
            else:
                trades = run_goldbb_backtest(rates, params, avg_spread)
                results = analyze_trades(trades, args.deposit)
                print_results(results)
                it_id = log_iteration("GoldBB", args.symbol, args.tf,
                                       {"baseline": True}, results, "Baseline M5 defaults")
                print(f"\nIteration #{it_id} logged.")
                save_trades(trades, f"GoldBB_{args.symbol}_{args.tf}")

        else:
            params = PatternParams(point=point)
            print(f"\n=== GoldPattern Backtest: {args.symbol} {args.tf} ===")
            print(f"  Pattern({params.pattern_candles}) Sim>={params.similarity} MinMatch>={params.min_matches}")
            print(f"  Lookback={params.lookback} | Score>={params.score_threshold}")

            trades = run_goldpattern_backtest(rates, params, avg_spread)
            results = analyze_trades(trades, args.deposit)
            print_results(results)
            it_id = log_iteration("GoldPattern", args.symbol, args.tf,
                                   {"baseline": True}, results, "Baseline M5 defaults")
            print(f"\nIteration #{it_id} logged.")
            save_trades(trades, f"GoldPattern_{args.symbol}_{args.tf}")

    finally:
        mt5.shutdown()


def run_bb_sweep(rates, point, args, avg_spread):
    """Parameter sweep for GoldBB — test key parameter variations."""
    print("\n=== PARAMETER SWEEP ===")

    sweep_configs = [
        # Baseline
        {"name": "Baseline M5", "params": {}},
        # BB variations
        {"name": "BB(14, 1.8)", "params": {"bb_period": 14, "bb_dev": 1.8, "bb_std_period": 15}},
        {"name": "BB(20, 2.2)", "params": {"bb_period": 20, "bb_dev": 2.2, "bb_std_period": 21}},
        {"name": "BB(25, 2.0)", "params": {"bb_period": 25, "bb_dev": 2.0, "bb_std_period": 26}},
        # TP/SL variations
        {"name": "TP=0.5 SL=1.0", "params": {"tp_atr": 0.50, "sl_atr": 1.0}},
        {"name": "TP=1.0 SL=1.5", "params": {"tp_atr": 1.0, "sl_atr": 1.5}},
        {"name": "TP=1.0 SL=2.0", "params": {"tp_atr": 1.0, "sl_atr": 2.0}},
        # Score threshold
        {"name": "Score>=55", "params": {"score_threshold": 55}},
        {"name": "Score>=75", "params": {"score_threshold": 75}},
        # Filter combos
        {"name": "No KC filter", "params": {"kc_enable": False}},
        {"name": "No VWAP", "params": {"vwap_enable": False}},
        {"name": "No StdDev", "params": {"stddev_enable": False}},
        {"name": "No ZLEMA", "params": {"zl_enable": False}},
        {"name": "ST only filter", "params": {"kc_enable": False, "vwap_enable": False,
                                                "stddev_enable": False, "zl_enable": False,
                                                "rsi_enable": False, "vol_enable": False}},
        # Touch vs close-back-inside
        {"name": "Touch mode", "params": {"close_back_inside": False}},
        # RSI variation
        {"name": "RSI(7) dev=25", "params": {"rsi_period": 7, "rsi_dev": 25.0}},
        {"name": "RSI(14) dev=15", "params": {"rsi_period": 14, "rsi_dev": 15.0}},
    ]

    print(f"\n{'Config':<22} | {'Trades':>6} | {'WR%':>5} | {'PF':>5} | {'Profit':>8} | {'DD':>6} | {'Sharpe':>6}")
    print("-" * 75)

    best_pf = 0
    best_config = ""

    for cfg in sweep_configs:
        params = BBParams(point=point)
        for k, v in cfg["params"].items():
            setattr(params, k, v)

        trades = run_goldbb_backtest(rates, params, avg_spread)
        r = analyze_trades(trades, args.deposit)

        print(f"{cfg['name']:<22} | {r['total_trades']:>6} | {r['win_rate']:>5.1f} | "
              f"{r['profit_factor']:>5.2f} | {r['total_profit']:>8.2f} | {r['max_dd_pct']:>5.1f}% | {r['sharpe']:>6.2f}")

        log_iteration("GoldBB", args.symbol, args.tf, cfg["params"], r, f"Sweep: {cfg['name']}")

        if r['profit_factor'] > best_pf and r['total_trades'] >= 20:
            best_pf = r['profit_factor']
            best_config = cfg['name']

    print(f"\nBest config: {best_config} (PF={best_pf:.2f})")


def print_results(results):
    """Pretty-print backtest results."""
    r = results
    print(f"\n{'─' * 45}")
    print(f"  Total trades:   {r['total_trades']}")
    print(f"  Wins/Losses:    {r['wins']}/{r['losses']}")
    print(f"  Win rate:       {r['win_rate']:.1f}%")
    print(f"  Profit factor:  {r['profit_factor']:.2f}")
    print(f"  Total profit:   ${r['total_profit']:.2f}")
    print(f"  Avg win:        ${r['avg_win']:.2f}")
    print(f"  Avg loss:       ${r['avg_loss']:.2f}")
    print(f"  Max drawdown:   ${r['max_drawdown']:.2f} ({r['max_dd_pct']:.1f}%)")
    print(f"  Sharpe ratio:   {r['sharpe']:.2f}")
    print(f"  Expectancy:     ${r['expectancy']:.2f}/trade")
    print(f"  Return:         {r['return_pct']:.1f}%")
    print(f"  Avg score:      {r['avg_score']:.0f}")
    print(f"{'─' * 45}")


def save_trades(trades, prefix):
    """Save trade list to JSON."""
    filepath = RESULTS_DIR / f"{prefix}_trades.json"
    data = [asdict(t) for t in trades]
    filepath.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"Trades saved: {filepath}")


if __name__ == "__main__":
    main()
