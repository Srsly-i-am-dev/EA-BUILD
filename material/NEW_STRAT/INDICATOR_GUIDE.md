# ABC Pattern Indicator - Enhanced with Trade Signals & TP/SL Guide

**Version:** 2.0 - Trade Signals Edition
**Last Updated:** 2026-03-16
**Compatibility:** PineScript v5

---

## 🎯 What's New

The enhanced ABC Pattern indicator now includes:

✅ **Automatic Trade Signals** - BUY at C (bullish) and SELL at C (bearish)
✅ **Dynamic TP/SL Calculation** - Based on geometric targets with customization
✅ **Dual SL Modes** - Choose between C-level % or Previous Pattern Target
✅ **Custom Override** - Optional manual TP/SL input for specific trades
✅ **Visual Display** - TP/SL lines drawn on chart (green=profit, red=loss)
✅ **Risk/Reward Ratio** - Calculated and displayed in alerts and info box
✅ **Webhook Compatible** - Alert messages formatted for automated trading system

---

## 📋 Feature Breakdown

### 1. Trade Signal Detection
When the ABC pattern completes and identifies the C point:
- **Bullish C Signal** → Generates BUY alert
- **Bearish C Signal** → Generates SELL alert

Signals only trigger once per pattern (when C first identified, not bul[1])

### 2. TP (Take Profit) Calculation

**Default TP:**
- Bullish: Uses geometric target formula = (B × C) ÷ A
- Bearish: Uses geometric target formula = (B × C) ÷ A

**Customization:**
- Add/subtract percentage via `TP Adjustment % beyond Target` input
  - Example: If target=100 and adjustment=+1%, TP=101
  - Negative values allowed (e.g., -0.5% = slightly below target)

**Manual Override:**
- Enable `Override TP with Custom Value?` input
- Enter exact price in `Custom TP Value` field
- Overrides both default and percentage-adjusted TP

### 3. SL (Stop Loss) Modes

**Bullish SL - Option 1: "C Level %"**
```
SL = C × (1 - bullSLPercent%)
Example: If C=100 and bullSLPercent=0.5%, SL=99.5
```
- Set via `Bull SL: % below C` input (default 0.5%)
- Simple, fixed percentage below entry

**Bullish SL - Option 2: "Prev Bear Target"**
```
SL = Previous bearish pattern target (eT)
Example: If last bear target was 98, SL=98
```
- Uses previous opposite-direction pattern target as SL
- More dynamic, based on prior support levels
- Falls back to C-level % if no previous bear pattern exists

**Bearish SL - Option 1: "C Level %"**
```
SL = C × (1 + bearSLPercent%)
Example: If C=100 and bearSLPercent=0.5%, SL=100.5
```
- Set via `Bear SL: % above C` input (default 0.5%)
- Simple, fixed percentage above entry

**Bearish SL - Option 2: "Prev Bull Target"**
```
SL = Previous bullish pattern target (bT)
Example: If last bull target was 102, SL=102
```
- Uses previous opposite-direction pattern target as SL
- More dynamic, based on prior resistance levels
- Falls back to C-level % if no previous bull pattern exists

**Manual Override:**
- Enable `Override SL with Custom Value?` input
- Enter exact price in `Custom SL Value` field
- Overrides both default modes

---

## 🎮 Input Parameters Guide

### Display Settings
```
Pivot Lookback:           10 (bars to look back for pivot highs/lows)
Show Buy Zone:            true
Show Sell Zone:           true
Show Target Line:         true
Show Failure Level:       true
Show ABC Path Lines:      true
Show % Labels:            true
Show TP/SL Lines:         true (NEW)
```

### Trading Signal Settings
```
Enable Trade Signals:     true - Turn on/off BUY/SELL signal generation

Bull SL Mode:             "C Level %" or "Prev Bear Target"
Bear SL Mode:             "C Level %" or "Prev Bull Target"

Bull SL: % below C:       0.5 (How much % below C for SL in mode 1)
Bear SL: % above C:       0.5 (How much % above C for SL in mode 1)

TP Adjustment:            0.0 (% to add/subtract from target TP)
                          Example: 1.0 = 1% above target
                                   -0.5 = 0.5% below target

Override TP:              false - Enable custom TP input
Custom TP Value:          0.0 (Exact price, or 0 to use auto)

Override SL:              false - Enable custom SL input
Custom SL Value:          0.0 (Exact price, or 0 to use auto)
```

### Color Settings
```
Buy Color:                Green (#00E676)
Sell Color:               Red (#FF1744)
Target Color:             Yellow (#FFD600)
Fail Color:               Orange (#FF6D00)
```

---

## 📊 Info Table (Top Right of Chart)

Displays real-time pattern data:

| Metric | Shows |
|--------|-------|
| **📈 Bull** | Active/Inactive status |
| **🎯 Bull Tgt** | Target price + % gain |
| **📈 Bull TP** | **NEW** - Take Profit level |
| **📉 Bear** | Active/Inactive status |
| **🎯 Bear Tgt** | Target price + % loss |
| **📉 Bear TP** | **NEW** - Take Profit level |
| **⚠️ Status** | Pattern health (Monitoring/FAILED) |

---

## 🚨 Alert Messages

### Bullish BUY Signal Alert

```
📈 BUY SIGNAL
Entry (C): 211.52
Target (TP): 211.62
Stop Loss (SL): 211.14
Risk/Reward: 1.5:1
```

**Parsed by Trading System:**
- Action: BUY
- Entry Price: 211.52
- TP Price: 211.62
- SL Price: 211.14
- Risk/Reward: 1.5 (you risk 1 to make 1.5)

### Bearish SELL Signal Alert

```
📉 SELL SIGNAL
Entry (C): 211.52
Target (TP): 211.42
Stop Loss (SL): 211.90
Risk/Reward: 2.0:1
```

**Parsed by Trading System:**
- Action: SELL
- Entry Price: 211.52
- TP Price: 211.42
- SL Price: 211.90
- Risk/Reward: 2.0 (you risk 1 to make 2)

---

## 🎯 Usage Scenarios

### Scenario 1: Default Settings (Recommended for Most)

**Settings:**
```
Bull SL Mode: "C Level %"
Bull SL %: 0.5%
Bear SL Mode: "C Level %"
Bear SL %: 0.5%
TP Adjustment: 0.0%
```

**What Happens:**
- Buy at C, Sell at Target (geometric)
- Stop Loss 0.5% below C (bullish) or above C (bearish)
- Clean, predictable entry/exit

---

### Scenario 2: Using Previous Pattern Targets as SL

**Settings:**
```
Bull SL Mode: "Prev Bear Target"
Bear SL Mode: "Prev Bull Target"
TP Adjustment: 0.0%
```

**What Happens:**
- Buy at C, Sell at Target
- SL placed at previous opposite pattern target
- More context-aware, uses prior support/resistance
- First pattern falls back to C ± 0.5% since no previous target

**Example on GBPJPY:**
```
Pattern 1 (Bear): Target = 211.30
  └─ Next Pattern (Bull): SL will be set at 211.30
     └─ When C identified → BUY with SL at 211.30

Pattern 2 (Bull): Target = 211.70
  └─ Next Pattern (Bear): SL will be set at 211.70
     └─ When C identified → SELL with SL at 211.70
```

---

### Scenario 3: Aggressive TP Adjustment

**Settings:**
```
Bull SL Mode: "C Level %"
Bear SL Mode: "C Level %"
TP Adjustment: +1.0%  (Move target 1% higher)
Bull SL %: 0.3%       (Tighter stop loss)
Bear SL %: 0.3%
```

**What Happens:**
- Tighter stops (more aggressive)
- TP targets pushed 1% beyond geometric target
- Higher win rate potential, but larger risk per stop

---

### Scenario 4: Manual TP/SL Override

**Settings:**
```
Override TP: true
Custom TP Value: 211.75
Override SL: true
Custom SL Value: 211.10
```

**What Happens:**
- All signals use FIXED TP=211.75, SL=211.10
- Ignores all other TP/SL calculation logic
- Best for specific setups or manual intervention

---

## 📈 Visual Guide

### What You'll See on Chart

```
                    🎯 TARGET (Yellow Dashed)
                         211.62
              ┃
              ┃
    ▼ B       ┃
   211.50    ┃        TP: 211.62 (Green Line)
    B────    ┃────────────────────────
   ────      ┃
    |  \     ┃
    |   \    ┃
    |    ──┐ ┃
    |      ▲ C
    |     211.52
    |      │  TP/SL displayed
    |      │  as dashed lines
    |      │
    |    SL: 211.14 (Red Line)
    |
    ▲ A
   211.30


Legend:
━━━━ Pattern A→B→C path (Green for Bull, Red for Bear)
╌╌╌╌ Target line (Yellow dashed)
────  TP line (Green dashed for Bull, Red dashed for Bear)
────  SL line (Red dashed for Bull, Green dashed for Bear)
```

---

## 🔗 Integration with Trading System

### How Alerts Are Sent

1. **When C is identified** → Alert condition triggers
2. **Alert message formatted** with all required data
3. **Two paths:**
   - **TradingView Alert:** Shows in-platform notification
   - **Webhook Alert:** If configured, sends to your trading system

### Webhook Message Format

Your trading system receives:
```
Signal: 📈 BUY SIGNAL
Entry (C): 211.52
Target (TP): 211.62
Stop Loss (SL): 211.14
Risk/Reward: 1.5:1
```

**Your System Should Parse:**
```json
{
  "action": "BUY",
  "entry_price": 211.52,
  "tp_price": 211.62,
  "sl_price": 211.14,
  "symbol": "GBPJPY",
  "risk_reward": 1.5
}
```

---

## ⚙️ Configuration for Your Trading System

### Recommended Setup

**For the forward testing system webhook:**

1. Load indicator on your trading chart
2. Configure alert to send webhook:
   - TradingView → Alerts → New Alert
   - Select: "ABC Pattern - Trade Signals..."
   - Condition: Any of the trade signal alerts (BUY/SELL)
   - Action: Webhook URL
   - URL: `http://localhost:5000/webhook` (for local testing)
   - Header: `X-Webhook-Token: <your-token>`

3. The webhook will receive alerts and your trading system processes:
   - Entry price (C level)
   - TP and SL levels
   - Generates market order with SL and TP

---

## 📋 Checklist: Before First Trade

- [ ] Load `abc_pattern_enhanced.txt` on your chart
- [ ] Test on historical data to see signal generation
- [ ] Verify TP/SL lines draw at correct levels
- [ ] Review alert messages for accuracy
- [ ] Configure webhook URL if using automated system
- [ ] Test with paper trading first (simulated mode)
- [ ] Monitor R:R ratio - aim for 1:1 or better
- [ ] Check that previous pattern targets make sense
- [ ] Adjust SL % if needed based on symbol volatility
- [ ] Only enable real trading after paper trading validation

---

## 🚀 Quick Start

1. **Copy code** from `abc_pattern_enhanced.txt`
2. **Open TradingView** → Create new indicator (Pine Script editor)
3. **Paste code** and save
4. **Add to chart** on your preferred timeframe (suggested: 4H, Daily)
5. **Adjust inputs** based on your strategy
6. **Enable alerts** for BUY and SELL signals
7. **Monitor first pattern** to verify TP/SL placement

---

## 🎓 Tips & Tricks

### Tip 1: Volatility-Adjusted SL
High volatility symbols → Use higher SL % (1.0%)
Low volatility symbols → Use lower SL % (0.2%)

### Tip 2: Testing SL Modes
- Start with "C Level %" for simplicity
- Graduate to "Prev Target" mode once comfortable
- Compare R:R ratios to see which works better for your symbol

### Tip 3: Optimize TP Adjustment
- Test -0.5% to find sweet spot between profit and win rate
- Higher adjustment = bigger TP but fewer hits
- Negative adjustment = more hits but smaller profit

### Tip 4: Risk Management
- Use Risk/Reward shown in alert to size positions
- Only trade if R:R ≥ 1.5:1
- Adjust TP % or SL % if R:R is too low

### Tip 5: Multi-Timeframe
- Use higher TF (4H, Daily) for longer holds
- Use lower TF (1H, 15m) for quicker trades
- TP/SL auto-scales to appropriate levels

---

## 🐛 Troubleshooting

### No Signals Generated
- **Check:** "Enable Trade Signals" is true
- **Check:** ABC patterns are visible on chart
- **Check:** C point must form for signal (not just A→B)

### TP/SL Lines Not Showing
- **Check:** "Show TP/SL Lines" is true
- **Check:** Bullish or Bearish pattern is currently active
- **Note:** Lines only show for current active pattern

### Alert Not Triggering
- **Check:** Pattern detection is working (ABC labels visible)
- **Check:** Enable "Webhook" and set URL if using automated system
- **Check:** TradingView alert is properly configured

### Previous Target Showing as 0
- **Info:** First pattern has no previous target
- **Action:** Falls back to C Level % mode automatically
- **Expected:** After first pattern, subsequent patterns will have targets

### Risk/Reward Calculation Shows Infinity
- **Cause:** SL too close to entry (very small SL)
- **Fix:** Increase SL % or use custom SL value

---

## 📞 Support & Questions

**For signal quality:**
- Adjust `Pivot Lookback` if patterns seem wrong
- Verify A→B→C sequence makes sense
- Check volume on C point

**For TP/SL placement:**
- Review `TP Adjustment` setting
- Compare both SL modes on historical data
- Test custom values first before automation

**For webhook integration:**
- Ensure webhook URL is correct
- Check trading system logs for received signals
- Verify alert message format matches expected input

---

**Version History:**
- v1.0 (Original) - ABC pattern visualization only
- v2.0 (Current) - Added trade signals, TP/SL, customization

**Created:** 2026-03-16
**Last Updated:** 2026-03-16
