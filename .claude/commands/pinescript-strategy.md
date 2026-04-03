---
description: Convert a PineScript v5 indicator into a backtestable strategy version with strategy.entry/exit calls, position sizing, and commission modeling. Pass the indicator file path as argument.
allowed-tools: ["Read", "Write", "Edit"]
---

You are an expert PineScript v5 developer. Convert the provided indicator into a backtestable strategy.

**Arguments:** $ARGUMENTS (format: "indicator_file_path")

**Output Location:** Replace `pinescript/indicators/` with `pinescript/strategies/` in the path, and append `_strategy` to the filename.

## Conversion Steps

### 1. Change indicator() to strategy()
```pinescript
// FROM:
indicator("Strategy Name", shorttitle="SHORT", overlay=true)

// TO:
strategy("Strategy Name [Strategy]", shorttitle="SHORT_strat", overlay=true,
         default_qty_type=strategy.percent_of_equity, default_qty_value=1,
         initial_capital=10000, commission_type=strategy.commission.cash_per_order,
         commission_value=0, slippage=2, pyramiding=0,
         calc_on_every_tick=false, process_orders_on_close=true)
```

### 2. Add Strategy Inputs (after existing inputs)
```pinescript
// ── STRATEGY SETTINGS ────────────────────────────────────────
strat_riskPct    = input.float(1.0,   "Risk % per Trade",    group="Strategy", minval=0.1, step=0.1)
strat_useATRSL   = input.bool(true,   "Use ATR-based SL",    group="Strategy")
strat_slMult     = input.float(1.5,   "SL ATR Multiplier",   group="Strategy", minval=0.1, step=0.1)
strat_tpMult     = input.float(2.0,   "TP ATR Multiplier",   group="Strategy", minval=0.1, step=0.1)
strat_atrLen     = input.int(14,      "ATR Length",           group="Strategy", minval=1)
```

### 3. Calculate Position Size and TP/SL
```pinescript
// ── STRATEGY TP/SL ───────────────────────────────────────────
strat_atr = ta.atr(strat_atrLen)
strat_sl = strat_useATRSL ? strat_atr * strat_slMult : na
strat_tp = strat_useATRSL ? strat_atr * strat_tpMult : na
```

### 4. Replace plotshape() Signals with strategy.entry/exit
```pinescript
// ── STRATEGY ENTRIES ─────────────────────────────────────────
if buySignal
    strategy.entry("Long", strategy.long)
    if not na(strat_sl)
        strategy.exit("Long Exit", "Long", stop=close - strat_sl, limit=close + strat_tp)

if sellSignal
    strategy.entry("Short", strategy.short)
    if not na(strat_sl)
        strategy.exit("Short Exit", "Short", stop=close + strat_sl, limit=close - strat_tp)
```

### 5. Keep Visual Elements
Keep all `plotshape()`, `plot()`, `line.new()`, `label.new()` calls — they still work in strategies and help visualize entries on the chart.

### 6. Remove alertcondition() and alert() Calls
Strategy versions don't need webhook alerts — those belong in the enhanced indicator version.

## Quality Checks
- [ ] `strategy()` call replaces `indicator()` with proper settings
- [ ] `strategy.entry()` for both Long and Short
- [ ] `strategy.exit()` with stop and limit prices
- [ ] Position sizing inputs added
- [ ] Commission/slippage configured
- [ ] `pyramiding=0` to prevent multiple entries
- [ ] All original visual elements preserved
- [ ] No `alertcondition()` or `alert()` calls remain
- [ ] File saved to `pinescript/strategies/` directory

Read the indicator file, convert it, and write the strategy version.
