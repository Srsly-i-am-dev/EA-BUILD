"""
MT5 Backtest Runner — Automated parameter optimization for GoldBB & GoldPattern EAs.

Usage:
    python mt5_backtest.py --ea GoldBB --symbol XAUUSD --tf M5 --period 2024.01.01-2025.01.01
    python mt5_backtest.py --ea GoldPattern --symbol XAUUSD --tf M1 --period 2024.06.01-2025.01.01
    python mt5_backtest.py --ea GoldBB --symbol EURUSD --tf M15 --optimize
    python mt5_backtest.py --forward --ea GoldBB --symbol XAUUSD  # forward test mode

Writes results to optimizer/results/ as JSON for the optimization agent to read.
"""

import MetaTrader5 as mt5
import json
import os
import sys
import time
import argparse
from datetime import datetime, timedelta
from pathlib import Path

# Paths
EA_BUILD_DIR = Path(r"C:\Users\DEV\OneDrive\Desktop\EA BUILD")
MQL5_DIR = Path(r"C:\Users\DEV\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5")
RESULTS_DIR = EA_BUILD_DIR / "optimizer" / "results"
SETS_DIR = EA_BUILD_DIR / "optimizer" / "sets"
MT5_TERMINAL = r"C:\Program Files\MetaTrader 5\terminal64.exe"

RESULTS_DIR.mkdir(parents=True, exist_ok=True)
SETS_DIR.mkdir(parents=True, exist_ok=True)


def init_mt5():
    """Initialize MT5 connection."""
    if not mt5.initialize():
        print(f"MT5 init failed: {mt5.last_error()}")
        return False
    info = mt5.terminal_info()
    if info:
        print(f"MT5 connected: {info.name} build {info.build}")
    return True


def shutdown_mt5():
    mt5.shutdown()


def get_account_info():
    """Get current account info for forward testing baseline."""
    info = mt5.account_info()
    if info is None:
        return {}
    return {
        "balance": info.balance,
        "equity": info.equity,
        "profit": info.profit,
        "margin_free": info.margin_free,
        "leverage": info.leverage,
        "server": info.server,
        "login": info.login,
    }


def get_symbol_info(symbol):
    """Get symbol trading parameters."""
    info = mt5.symbol_info(symbol)
    if info is None:
        return None
    return {
        "symbol": symbol,
        "point": info.point,
        "digits": info.digits,
        "spread": info.spread,
        "volume_min": info.volume_min,
        "volume_max": info.volume_max,
        "volume_step": info.volume_step,
        "trade_tick_value": info.trade_tick_value,
    }


def get_historical_data(symbol, timeframe_str, bars=5000):
    """Fetch historical OHLCV data for analysis."""
    tf_map = {
        "M1": mt5.TIMEFRAME_M1,
        "M5": mt5.TIMEFRAME_M5,
        "M15": mt5.TIMEFRAME_M15,
        "M30": mt5.TIMEFRAME_M30,
        "H1": mt5.TIMEFRAME_H1,
        "H4": mt5.TIMEFRAME_H4,
        "D1": mt5.TIMEFRAME_D1,
    }
    tf = tf_map.get(timeframe_str, mt5.TIMEFRAME_M5)

    rates = mt5.copy_rates_from_pos(symbol, tf, 0, bars)
    if rates is None or len(rates) == 0:
        return None

    return [{
        "time": int(r[0]),
        "open": float(r[1]),
        "high": float(r[2]),
        "low": float(r[3]),
        "close": float(r[4]),
        "tick_volume": int(r[5]),
        "spread": int(r[6]),
        "real_volume": int(r[7]),
    } for r in rates]


def get_open_positions(ea_magic=None):
    """Get currently open positions, optionally filtered by magic number."""
    positions = mt5.positions_get()
    if positions is None:
        return []

    result = []
    for pos in positions:
        if ea_magic and pos.magic != ea_magic:
            continue
        result.append({
            "ticket": pos.ticket,
            "symbol": pos.symbol,
            "type": "BUY" if pos.type == 0 else "SELL",
            "volume": pos.volume,
            "price_open": pos.price_open,
            "price_current": pos.price_current,
            "sl": pos.sl,
            "tp": pos.tp,
            "profit": pos.profit,
            "swap": pos.swap,
            "magic": pos.magic,
            "comment": pos.comment,
            "time": int(pos.time),
        })
    return result


def get_deal_history(ea_magic=None, days_back=30):
    """Get closed trade history for performance analysis."""
    from_date = datetime.now() - timedelta(days=days_back)
    to_date = datetime.now()

    deals = mt5.history_deals_get(from_date, to_date)
    if deals is None:
        return []

    result = []
    for deal in deals:
        if ea_magic and deal.magic != ea_magic:
            continue
        if deal.entry == 1:  # DEAL_ENTRY_OUT
            result.append({
                "ticket": deal.ticket,
                "symbol": deal.symbol,
                "type": "BUY" if deal.type == 0 else "SELL",
                "volume": deal.volume,
                "price": deal.price,
                "profit": deal.profit,
                "swap": deal.swap,
                "commission": deal.commission,
                "magic": deal.magic,
                "comment": deal.comment,
                "time": int(deal.time),
            })
    return result


def calculate_performance(deals):
    """Calculate performance metrics from deal history."""
    if not deals:
        return {
            "total_trades": 0, "wins": 0, "losses": 0,
            "win_rate": 0, "profit_factor": 0, "total_profit": 0,
            "avg_win": 0, "avg_loss": 0, "max_dd": 0,
            "sharpe": 0, "expectancy": 0,
        }

    total = len(deals)
    profits = [d["profit"] + d.get("swap", 0) + d.get("commission", 0) for d in deals]

    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]

    gross_profit = sum(wins) if wins else 0
    gross_loss = abs(sum(losses)) if losses else 0

    # Running equity curve for drawdown
    equity = 0
    peak = 0
    max_dd = 0
    for p in profits:
        equity += p
        if equity > peak:
            peak = equity
        dd = peak - equity
        if dd > max_dd:
            max_dd = dd

    # Sharpe approximation
    import math
    avg_profit = sum(profits) / total if total > 0 else 0
    variance = sum((p - avg_profit) ** 2 for p in profits) / total if total > 1 else 0
    std_dev = math.sqrt(variance) if variance > 0 else 1
    sharpe = (avg_profit / std_dev) * math.sqrt(252) if std_dev > 0 else 0

    return {
        "total_trades": total,
        "wins": len(wins),
        "losses": len(losses),
        "win_rate": round(len(wins) / total * 100, 1) if total > 0 else 0,
        "profit_factor": round(gross_profit / gross_loss, 2) if gross_loss > 0 else 999.0,
        "total_profit": round(sum(profits), 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "avg_win": round(sum(wins) / len(wins), 2) if wins else 0,
        "avg_loss": round(sum(losses) / len(losses), 2) if losses else 0,
        "max_drawdown": round(max_dd, 2),
        "sharpe_ratio": round(sharpe, 2),
        "expectancy": round(avg_profit, 2),
        "best_trade": round(max(profits), 2) if profits else 0,
        "worst_trade": round(min(profits), 2) if profits else 0,
    }


def generate_set_file(ea_name, params, filename=None):
    """Generate .set parameter file for MT5 Strategy Tester."""
    if filename is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{ea_name}_{timestamp}.set"

    filepath = SETS_DIR / filename
    lines = []
    for key, value in params.items():
        if isinstance(value, bool):
            v = 1 if value else 0
            lines.append(f"{key}={v}||0||0||0||N")
        elif isinstance(value, float):
            lines.append(f"{key}={value}||0.0||0.0||0.0||N")
        else:
            lines.append(f"{key}={value}||0||0||0||N")

    filepath.write_text("\n".join(lines), encoding="utf-8")
    print(f"Set file written: {filepath}")
    return str(filepath)


def generate_ini_file(ea_name, symbol, tf, date_from, date_to, set_file=None):
    """Generate .ini config for MT5 command-line backtesting."""
    tf_map = {"M1": "1", "M5": "5", "M15": "15", "M30": "30", "H1": "60", "H4": "240", "D1": "1440"}
    period = tf_map.get(tf, "5")

    # EA path relative to MQL5/Experts
    ea_path = f"EA BUILD\\\\{ea_name}"

    report_path = str(EA_BUILD_DIR / "optimizer" / "results" / f"{ea_name}_{symbol}_{tf}")

    ini_content = f"""[Tester]
Expert={ea_path}
Symbol={symbol}
Period={period}
Deposit=10000
Leverage=100
Model=1
ExecutionMode=0
Optimization=0
FromDate={date_from}
ToDate={date_to}
ForwardMode=0
Report={report_path}
ReplaceReport=1
ShutdownTerminal=1
UseLocal=1
Visual=0
"""
    if set_file:
        ini_content += f"ExpertParameters={set_file}\n"

    ini_path = EA_BUILD_DIR / "optimizer" / f"test_{ea_name}.ini"
    ini_path.write_text(ini_content, encoding="utf-8")
    print(f"INI file written: {ini_path}")
    return str(ini_path)


def run_backtest_cli(ini_file):
    """Run MT5 backtest via command line (non-interactive)."""
    import subprocess

    cmd = f'"{MT5_TERMINAL}" /config:"{ini_file}"'
    print(f"Running: {cmd}")

    try:
        result = subprocess.run(cmd, shell=True, timeout=300, capture_output=True, text=True)
        print(f"MT5 exited with code {result.returncode}")
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print("MT5 backtest timed out (5 min)")
        return False


def read_backtest_report(ea_name, symbol, tf):
    """Read MT5 backtest HTML/XML report and parse key metrics."""
    report_name = f"{ea_name}_{symbol}_{tf}"
    # MT5 saves reports to the terminal data folder
    report_dir = MQL5_DIR.parent / "reports"

    for ext in [".xml", ".htm", ".html"]:
        report_path = report_dir / f"{report_name}{ext}"
        if report_path.exists():
            content = report_path.read_text(encoding="utf-8", errors="ignore")
            return {"path": str(report_path), "content_length": len(content), "raw": content[:5000]}

    return {"error": "Report not found", "searched": str(report_dir)}


def forward_test_snapshot(ea_magic, symbol, days_back=7):
    """Take a forward test snapshot — current positions + recent deal history."""
    positions = get_open_positions(ea_magic)
    deals = get_deal_history(ea_magic, days_back)
    perf = calculate_performance(deals)
    account = get_account_info()

    snapshot = {
        "timestamp": datetime.now().isoformat(),
        "ea_magic": ea_magic,
        "symbol": symbol,
        "account": account,
        "open_positions": positions,
        "closed_deals_count": len(deals),
        "performance": perf,
        "deals": deals[-20:],  # Last 20 for context
    }

    # Save snapshot
    filename = f"forward_{ea_magic}_{symbol}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    filepath = RESULTS_DIR / filename
    filepath.write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
    print(f"Forward snapshot saved: {filepath}")
    return snapshot


# ──────────────────────────────────────────────────────────────
# Default parameter sets per EA and TF
# ──────────────────────────────────────────────────────────────

GOLDBB_DEFAULTS = {
    "M1": {
        "InpBBTimeframe": 0, "InpBBPeriod": 14, "InpBBDeviation": 1.8,
        "InpBBCloseBackInside": 0, "InpBBTouchBuffer": 10.0,
        "InpBBSTATR": 7, "InpBBSTMult": 1.5,
        "InpBBKCEnable": 1, "InpBBKCEMA": 14, "InpBBKCATR": 7, "InpBBKCMult": 1.5,
        "InpBBZLEnable": 1, "InpBBZLLength": 50,
        "InpBBVWAPEnable": 1, "InpBBStdDevEnable": 1,
        "InpBBRSIEnable": 1, "InpBBRSIPeriod": 7, "InpBBRSIDeviation": 25.0,
        "InpBBVolEnable": 1, "InpBBVolMult": 1.3,
        "InpBBATRPeriod": 7, "InpBBATRMinGate": 0.20,
        "InpBBTP_ATR": 0.50, "InpBBSL_ATR": 1.00,
        "InpBBBaseLots": 0.10, "InpBBMaxSpread": 40, "InpBBScoreThreshold": 65,
        "InpBBMagic": 84590,
    },
    "M5": {
        "InpBBTimeframe": 1, "InpBBPeriod": 20, "InpBBDeviation": 2.0,
        "InpBBCloseBackInside": 1, "InpBBTouchBuffer": 10.0,
        "InpBBSTATR": 7, "InpBBSTMult": 2.0,
        "InpBBKCEnable": 1, "InpBBKCEMA": 20, "InpBBKCATR": 10, "InpBBKCMult": 2.0,
        "InpBBZLEnable": 1, "InpBBZLLength": 70,
        "InpBBVWAPEnable": 1, "InpBBStdDevEnable": 1,
        "InpBBRSIEnable": 1, "InpBBRSIPeriod": 10, "InpBBRSIDeviation": 20.0,
        "InpBBVolEnable": 1, "InpBBVolMult": 1.2,
        "InpBBATRPeriod": 14, "InpBBATRMinGate": 0.30,
        "InpBBTP_ATR": 0.75, "InpBBSL_ATR": 1.50,
        "InpBBBaseLots": 0.10, "InpBBMaxSpread": 40, "InpBBScoreThreshold": 65,
        "InpBBMagic": 84590,
    },
    "M15": {
        "InpBBTimeframe": 2, "InpBBPeriod": 20, "InpBBDeviation": 2.2,
        "InpBBCloseBackInside": 1, "InpBBTouchBuffer": 10.0,
        "InpBBSTATR": 10, "InpBBSTMult": 2.5,
        "InpBBKCEnable": 1, "InpBBKCEMA": 20, "InpBBKCATR": 14, "InpBBKCMult": 2.5,
        "InpBBZLEnable": 1, "InpBBZLLength": 100,
        "InpBBVWAPEnable": 1, "InpBBStdDevEnable": 1,
        "InpBBRSIEnable": 1, "InpBBRSIPeriod": 14, "InpBBRSIDeviation": 15.0,
        "InpBBVolEnable": 1, "InpBBVolMult": 1.1,
        "InpBBATRPeriod": 14, "InpBBATRMinGate": 0.40,
        "InpBBTP_ATR": 1.00, "InpBBSL_ATR": 2.00,
        "InpBBBaseLots": 0.10, "InpBBMaxSpread": 40, "InpBBScoreThreshold": 65,
        "InpBBMagic": 84590,
    },
}

GOLDPATTERN_DEFAULTS = {
    "M1": {
        "InpPTimeframe": 0, "InpPPatternCandles": 4, "InpPSimilarity": 0.85,
        "InpPMinMatches": 8, "InpPMinAccuracy": 62.0,
        "InpPLookbackBars": 3000, "InpPFutureBars": 8,
        "InpPSTEnable": 1, "InpPSTATR": 7, "InpPSTMult": 1.5,
        "InpPZLEnable": 1, "InpPZLLength": 50,
        "InpPVWAPEnable": 1, "InpPStdDevEnable": 1,
        "InpPRSIEnable": 1, "InpPRSIPeriod": 7, "InpPRSIDeviation": 25.0,
        "InpPVolEnable": 1, "InpPVolMult": 1.3,
        "InpPATRPeriod": 7, "InpPATRMinGate": 0.20,
        "InpPTP_ATR": 0.50, "InpPSL_ATR": 1.00,
        "InpPBaseLots": 0.10, "InpPMaxSpread": 40, "InpPScoreThreshold": 65,
        "InpPMagic": 84600,
    },
    "M5": {
        "InpPTimeframe": 1, "InpPPatternCandles": 5, "InpPSimilarity": 0.80,
        "InpPMinMatches": 10, "InpPMinAccuracy": 60.0,
        "InpPLookbackBars": 5000, "InpPFutureBars": 10,
        "InpPSTEnable": 1, "InpPSTATR": 7, "InpPSTMult": 2.0,
        "InpPZLEnable": 1, "InpPZLLength": 70,
        "InpPVWAPEnable": 1, "InpPStdDevEnable": 1,
        "InpPRSIEnable": 1, "InpPRSIPeriod": 10, "InpPRSIDeviation": 20.0,
        "InpPVolEnable": 1, "InpPVolMult": 1.2,
        "InpPATRPeriod": 14, "InpPATRMinGate": 0.30,
        "InpPTP_ATR": 0.75, "InpPSL_ATR": 1.50,
        "InpPBaseLots": 0.10, "InpPMaxSpread": 40, "InpPScoreThreshold": 65,
        "InpPMagic": 84600,
    },
    "M15": {
        "InpPTimeframe": 2, "InpPPatternCandles": 8, "InpPSimilarity": 0.78,
        "InpPMinMatches": 12, "InpPMinAccuracy": 58.0,
        "InpPLookbackBars": 5000, "InpPFutureBars": 12,
        "InpPSTEnable": 1, "InpPSTATR": 10, "InpPSTMult": 2.5,
        "InpPZLEnable": 1, "InpPZLLength": 100,
        "InpPVWAPEnable": 1, "InpPStdDevEnable": 1,
        "InpPRSIEnable": 1, "InpPRSIPeriod": 14, "InpPRSIDeviation": 15.0,
        "InpPVolEnable": 1, "InpPVolMult": 1.1,
        "InpPATRPeriod": 14, "InpPATRMinGate": 0.40,
        "InpPTP_ATR": 1.00, "InpPSL_ATR": 2.00,
        "InpPBaseLots": 0.10, "InpPMaxSpread": 40, "InpPScoreThreshold": 65,
        "InpPMagic": 84600,
    },
}


def analyze_market_conditions(symbol, tf="M5"):
    """Analyze current market conditions to inform parameter selection."""
    data = get_historical_data(symbol, tf, 500)
    if not data:
        return {"error": "No data"}

    closes = [d["close"] for d in data]
    highs = [d["high"] for d in data]
    lows = [d["low"] for d in data]
    volumes = [d["tick_volume"] for d in data]

    # ATR approximation
    trs = []
    for i in range(1, len(data)):
        tr = max(
            highs[i] - lows[i],
            abs(highs[i] - closes[i-1]),
            abs(lows[i] - closes[i-1])
        )
        trs.append(tr)

    atr_14 = sum(trs[-14:]) / 14 if len(trs) >= 14 else 0
    atr_50 = sum(trs[-50:]) / 50 if len(trs) >= 50 else 0

    # Volatility regime
    import math
    mean_close = sum(closes[-20:]) / 20
    std_dev = math.sqrt(sum((c - mean_close)**2 for c in closes[-20:]) / 20)

    mean_close_50 = sum(closes[-50:]) / 50
    std_dev_50 = math.sqrt(sum((c - mean_close_50)**2 for c in closes[-50:]) / 50)

    vol_ratio = std_dev / std_dev_50 if std_dev_50 > 0 else 1.0

    # Average spread
    spreads = [d["spread"] for d in data[-100:]]
    avg_spread = sum(spreads) / len(spreads) if spreads else 0

    # Average volume
    avg_vol = sum(volumes[-50:]) / 50 if len(volumes) >= 50 else 0

    # Trend (simple: price vs SMA50)
    sma50 = sum(closes[-50:]) / 50 if len(closes) >= 50 else closes[-1]
    trend = "BULLISH" if closes[-1] > sma50 else "BEARISH"

    return {
        "symbol": symbol,
        "timeframe": tf,
        "current_price": closes[-1],
        "atr_14": round(atr_14, 4),
        "atr_50": round(atr_50, 4),
        "std_dev_20": round(std_dev, 4),
        "vol_ratio": round(vol_ratio, 2),
        "avg_spread": round(avg_spread, 1),
        "avg_volume": round(avg_vol, 0),
        "sma50": round(sma50, 4),
        "trend": trend,
        "volatility": "HIGH" if vol_ratio > 1.5 else ("LOW" if vol_ratio < 0.7 else "NORMAL"),
        "bars_analyzed": len(data),
    }


def copy_ea_files():
    """Copy EA source files to MT5 MQL5/Experts folder for compilation."""
    import shutil

    dest_base = MQL5_DIR / "Experts" / "EA BUILD"
    dest_base.mkdir(parents=True, exist_ok=True)

    # Folders to copy
    folders = ["Core", "Indicators", "Trading", "Risk", "Filters", "Utils", "Scalp", "GoldEA", "Grid", "Panel"]
    # Root-level EA files
    ea_files = ["GoldBB.mq5", "GoldPattern.mq5", "WakaScalp.mq5", "WakaGrid.mq5"]

    copied = 0
    for f in ea_files:
        src = EA_BUILD_DIR / f
        if src.exists():
            shutil.copy2(str(src), str(dest_base / f))
            copied += 1
            print(f"  Copied {f}")

    for folder in folders:
        src_dir = EA_BUILD_DIR / folder
        if src_dir.exists():
            dest_dir = dest_base / folder
            dest_dir.mkdir(parents=True, exist_ok=True)
            count = 0
            for src_file in src_dir.rglob("*"):
                if src_file.is_file():
                    rel = src_file.relative_to(src_dir)
                    dst = dest_dir / rel
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    try:
                        shutil.copy2(str(src_file), str(dst))
                        count += 1
                    except PermissionError:
                        print(f"  SKIP (locked): {rel}")
            copied += count
            print(f"  Copied {folder}/ ({count} files)")

    print(f"Total: {copied} files copied to {dest_base}")
    return str(dest_base)


def compile_ea(ea_name):
    """Compile EA using MT5 terminal (metaeditor)."""
    import subprocess

    # Try metaeditor64.exe in same dir as terminal
    me_path = Path(MT5_TERMINAL).parent / "metaeditor64.exe"
    ea_path = MQL5_DIR / "Experts" / "EA BUILD" / f"{ea_name}.mq5"

    if not me_path.exists():
        print(f"MetaEditor not found at {me_path}")
        print("Please compile manually in MetaEditor.")
        return False

    if not ea_path.exists():
        print(f"EA source not found: {ea_path}")
        print("Run --copy first to copy files.")
        return False

    log_file = EA_BUILD_DIR / "optimizer" / f"compile_{ea_name}.log"
    cmd = f'"{me_path}" /compile:"{ea_path}" /log:"{log_file}" /inc:"{MQL5_DIR}"'
    print(f"Compiling {ea_name}...")

    try:
        result = subprocess.run(cmd, shell=True, timeout=60, capture_output=True, text=True)
        if log_file.exists():
            log_content = log_file.read_text(encoding="utf-16-le", errors="ignore")
            print(log_content[-2000:] if len(log_content) > 2000 else log_content)
            if "0 error" in log_content.lower():
                print(f"{ea_name} compiled successfully!")
                return True
            else:
                print(f"{ea_name} compilation had errors.")
                return False
        print(f"MetaEditor exited with code {result.returncode}")
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print("Compilation timed out (60s)")
        return False


def log_iteration(ea, symbol, tf, params_changed, results, notes, next_action):
    """Append an iteration to the iteration log."""
    log_path = RESULTS_DIR / "iteration_log.json"

    if log_path.exists():
        data = json.loads(log_path.read_text(encoding="utf-8"))
    else:
        data = {"iterations": []}

    iteration_id = len(data["iterations"]) + 1
    entry = {
        "id": iteration_id,
        "timestamp": datetime.now().isoformat(),
        "ea": ea,
        "symbol": symbol,
        "tf": tf,
        "params_changed": params_changed,
        "results": results,
        "notes": notes,
        "next_action": next_action,
    }
    data["iterations"].append(entry)
    log_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"Iteration {iteration_id} logged to {log_path}")
    return iteration_id


def get_iteration_history():
    """Read iteration log for analysis."""
    log_path = RESULTS_DIR / "iteration_log.json"
    if not log_path.exists():
        return {"iterations": []}
    return json.loads(log_path.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description="MT5 Backtest Runner for GoldBB/GoldPattern")
    parser.add_argument("--ea", choices=["GoldBB", "GoldPattern"], default="GoldBB")
    parser.add_argument("--symbol", default="XAUUSD")
    parser.add_argument("--tf", choices=["M1", "M5", "M15"], default="M5")
    parser.add_argument("--period", default="2024.01.01-2025.01.01", help="date range: from-to")
    parser.add_argument("--optimize", action="store_true", help="Generate .ini for optimization run")
    parser.add_argument("--forward", action="store_true", help="Take forward test snapshot")
    parser.add_argument("--analyze", action="store_true", help="Analyze market conditions")
    parser.add_argument("--gen-set", action="store_true", help="Generate .set file with defaults")
    parser.add_argument("--magic", type=int, default=0, help="Magic number filter")
    parser.add_argument("--history", type=int, default=30, help="Days of history for forward test")
    parser.add_argument("--copy", action="store_true", help="Copy EA files to MT5 folder")
    parser.add_argument("--compile", action="store_true", help="Compile EA in MetaEditor")
    parser.add_argument("--log-iter", action="store_true", help="Log iteration results")
    parser.add_argument("--show-log", action="store_true", help="Show iteration history")
    parser.add_argument("--params-json", default="", help="JSON string of changed params for logging")
    parser.add_argument("--notes", default="", help="Notes for iteration log")

    args = parser.parse_args()

    # Commands that don't need MT5 connection
    if args.copy:
        dest = copy_ea_files()
        print(f"\nFiles copied to: {dest}")
        print("Now compile in MetaEditor or use --compile flag.")
        return

    if args.compile:
        compile_ea(args.ea)
        return

    if args.show_log:
        history = get_iteration_history()
        if not history["iterations"]:
            print("No iterations logged yet.")
        else:
            print(f"\n{'ID':>3} | {'EA':<12} | {'Symbol':<8} | {'TF':<4} | {'PF':>5} | {'WR%':>5} | {'DD%':>5} | {'Trades':>6} | {'Profit':>8}")
            print("-" * 75)
            for it in history["iterations"]:
                r = it.get("results", {})
                print(f"{it['id']:>3} | {it['ea']:<12} | {it['symbol']:<8} | {it['tf']:<4} | "
                      f"{r.get('pf', 0):>5.2f} | {r.get('wr', 0):>5.1f} | {r.get('dd', 0):>5.1f} | "
                      f"{r.get('trades', 0):>6} | {r.get('profit', 0):>8.2f}")
            print(f"\nTotal iterations: {len(history['iterations'])}")
            best = max(history["iterations"], key=lambda x: x.get("results", {}).get("pf", 0))
            print(f"Best PF: iteration #{best['id']} — PF={best['results'].get('pf', 0):.2f}")
        return

    if not init_mt5():
        sys.exit(1)

    try:
        if args.log_iter:
            # Log an iteration with forward test snapshot as results
            magic = args.magic or (84590 if args.ea == "GoldBB" else 84600)
            deals = get_deal_history(magic, args.history)
            perf = calculate_performance(deals)
            params_changed = json.loads(args.params_json) if args.params_json else {}
            results = {
                "pf": perf["profit_factor"],
                "wr": perf["win_rate"],
                "dd": perf["max_drawdown"],
                "trades": perf["total_trades"],
                "profit": perf["total_profit"],
                "sharpe": perf["sharpe_ratio"],
            }
            log_iteration(args.ea, args.symbol, args.tf, params_changed, results,
                         args.notes or "Auto-logged", "Review and adjust")
            print(json.dumps(results, indent=2))

        elif args.analyze:
            result = analyze_market_conditions(args.symbol, args.tf)
            print(json.dumps(result, indent=2))
            filepath = RESULTS_DIR / f"analysis_{args.symbol}_{args.tf}.json"
            filepath.write_text(json.dumps(result, indent=2))
            print(f"Saved: {filepath}")

        elif args.forward:
            magic = args.magic or (84590 if args.ea == "GoldBB" else 84600)
            snapshot = forward_test_snapshot(magic, args.symbol, args.history)
            print(json.dumps(snapshot["performance"], indent=2))

        elif args.gen_set:
            defaults = GOLDBB_DEFAULTS if args.ea == "GoldBB" else GOLDPATTERN_DEFAULTS
            params = defaults.get(args.tf, defaults["M5"])
            set_file = generate_set_file(args.ea, params)
            print(f"Generated: {set_file}")

        elif args.optimize:
            defaults = GOLDBB_DEFAULTS if args.ea == "GoldBB" else GOLDPATTERN_DEFAULTS
            params = defaults.get(args.tf, defaults["M5"])
            set_file = generate_set_file(args.ea, params)
            dates = args.period.split("-")
            ini_file = generate_ini_file(args.ea, args.symbol, args.tf, dates[0], dates[1], set_file)
            print(f"INI ready: {ini_file}")
            print(f"Run in MT5: terminal64.exe /config:\"{ini_file}\"")

        else:
            # Default: generate set + ini for single backtest run
            defaults = GOLDBB_DEFAULTS if args.ea == "GoldBB" else GOLDPATTERN_DEFAULTS
            params = defaults.get(args.tf, defaults["M5"])
            set_file = generate_set_file(args.ea, params)
            dates = args.period.split("-")
            ini_file = generate_ini_file(args.ea, args.symbol, args.tf, dates[0], dates[1], set_file)

            print(f"\nBacktest config ready:")
            print(f"  EA: {args.ea}")
            print(f"  Symbol: {args.symbol}")
            print(f"  TF: {args.tf}")
            print(f"  Period: {args.period}")
            print(f"  Set file: {set_file}")
            print(f"  INI file: {ini_file}")
            print(f"\nTo run: terminal64.exe /config:\"{ini_file}\"")

    finally:
        shutdown_mt5()


if __name__ == "__main__":
    main()
