---
description: Start the EA optimization loop — backtest, analyze, review material, adjust params, repeat until profitable
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, TodoWrite, WebSearch, WebFetch
---

# EA Optimization Loop

The user wants to optimize their MT5 Expert Advisors. Run the full optimization cycle.

## Arguments
- `$ARGUMENTS` — Can specify: EA name (GoldBB/GoldPattern), symbol (XAUUSD), timeframe (M1/M5/M15), or "forward" for forward test mode. If empty, optimize both EAs on XAUUSD M5.

## Steps

### 1. Setup
- Parse arguments from `$ARGUMENTS` to determine which EA, symbol, and timeframe
- Verify MT5 connection: `python "C:/Users/DEV/OneDrive/Desktop/EA BUILD/optimizer/mt5_backtest.py" --analyze --symbol XAUUSD --tf M5`
- Check if EA files are compiled in MT5 (`C:\Users\DEV\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\`)

### 2. Copy & Compile EAs (if needed)
Copy these folders from `C:\Users\DEV\OneDrive\Desktop\EA BUILD\` to MT5's `MQL5\Experts\EA BUILD\`:
- `GoldBB.mq5`, `GoldPattern.mq5`
- `GoldEA/` folder (all .mqh files)
- `Core/` folder
- `Indicators/` folder
- `Trading/` folder
- `Risk/` folder
- `Filters/` folder
- `Utils/` folder
- `Scalp/` folder

Then compile via MT5 terminal.

### 3. Launch Optimization Agent
Use the `ea-optimizer` agent to run the iterative optimization loop. Pass it:
- EA name, symbol, timeframe from parsed arguments
- Current iteration number (check `optimizer/results/iteration_log.json`)
- Previous best results if any

### 4. Report Results
After the agent completes, summarize:
- Best parameter set found
- Performance metrics (PF, win rate, drawdown, Sharpe)
- Whether ready for forward testing
- Next recommended action
