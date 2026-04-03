---
description: Convert a trading algorithm text file into a complete PineScript v5 indicator. Pass the source file path and strategy name as arguments.
allowed-tools: ["Read", "Write", "Glob", "Grep"]
---

You are an expert PineScript v5 developer. Convert the provided trading algorithm into a complete, compilable PineScript v5 indicator.

**Arguments:** $ARGUMENTS (format: "source_file_path strategy_name")

**Output Location:** `pinescript/indicators/<strategy_name>.pine`

## Conversion Rules

### From cAlgo C# to PineScript v5:
- `[Parameter("name", DefaultValue=X)]` → `input.int(X, "name")` / `input.float(X, "name")` / `input.bool(X, "name")`
- `[Parameter("name", DefaultValue=X, Group="group")]` → add `group="group"` to input
- `OnBar()` logic → runs implicitly on each bar in Pine
- `Bars.HighPrices[i]` → `high[i]`
- `Bars.LowPrices[i]` → `low[i]`
- `Bars.ClosePrices[i]` → `close[i]`
- `Bars.OpenPrices[i]` → `open[i]`
- `Indicators.ExponentialMovingAverage(source, period)` → `ta.ema(source, period)`
- `Indicators.AverageTrueRange(period)` → `ta.atr(period)`
- `Symbol.Bid` / `Symbol.Ask` → `close` (approximation in indicator mode)
- `ExecuteMarketOrder(type, vol, label, sl, tp)` → set signal boolean to true + plot shape
- `Math.Abs(x)` → `math.abs(x)`
- `Math.Max(a,b)` / `Math.Min(a,b)` → `math.max(a,b)` / `math.min(a,b)`
- `Math.Round(x, d)` → `math.round(x, d)` (Pine uses `math.round()`)
- `for` loops → same syntax in Pine (but limited to ~500 iterations)
- `Print()` / `Chart.DrawText()` → `label.new()` or info table

### From PineScript v6 to v5:
- `//@version=6` → `//@version=5`
- `method funcName(self)` → regular function `funcName(param)`
- `import Library/Name/Version` → inline the library code
- `type TypeName` UDTs → use arrays or tuples (or keep if v5 supports)
- `input.enum()` → `input.string()` with options list

### From Educational Notes:
- Extract the core logic described in the notes
- Implement each indicator mentioned using `ta.*` built-in functions
- Create explicit buy/sell boolean conditions from the described rules
- Use reasonable defaults for any parameters not explicitly specified

## Output Template

```pinescript
//@version=5
indicator("Strategy Name", shorttitle="SHORT", overlay=true, max_labels_count=500, max_lines_count=500)

// ── INPUTS ───────────────────────────────────────────────────
// [grouped inputs here]

// ── CALCULATIONS ─────────────────────────────────────────────
// [core indicator calculations]

// ── SIGNALS ──────────────────────────────────────────────────
buySignal = false  // [buy condition]
sellSignal = false // [sell condition]

// ── VISUALS ──────────────────────────────────────────────────
plotshape(buySignal, "Buy", shape.triangleup, location.belowbar, color.lime, size=size.small)
plotshape(sellSignal, "Sell", shape.triangledown, location.abovebar, color.red, size=size.small)
// [additional plots, lines, labels]
```

## Quality Checks
- [ ] `//@version=5` header present
- [ ] `indicator()` call with title and shorttitle
- [ ] All inputs use `input.*()` functions with groups
- [ ] Buy/sell signals are boolean variables
- [ ] `plotshape()` for signal visualization
- [ ] No `strategy.*` calls (this is an indicator)
- [ ] No syntax errors (check parentheses, brackets, quotes)
- [ ] All referenced variables are defined before use

Read the source file, convert it, and write the output to `pinescript/indicators/<strategy_name>.pine`.
