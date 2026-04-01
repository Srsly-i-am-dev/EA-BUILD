# ABC Pattern Indicator v2.0 - Quick Reference Card

**Print this page or bookmark it!**

---

## 🚀 Getting Started (5 Minutes)

### Load Indicator
```
1. TradingView → Pine Script Editor → Create New
2. Paste code from: abc_pattern_enhanced.txt
3. Add to chart (GBPJPY, 4H or Daily recommended)
4. Done! ABC labels should appear
```

### Configure Inputs
```
Left-click chart → Settings → inputs
─────────────────────────────────
Bull SL Mode:       "C Level %" or "Prev Bear Target"
Bull SL %:          0.5 (adjust for volatility)
Bear SL Mode:       "C Level %" or "Prev Bull Target"
Bear SL %:          0.5 (adjust for volatility)
TP Adjustment:      0.0 (or +1.0 for higher targets)
Show TP/SL Lines:   true (to see on chart)
```

### What You'll See
```
📈 Bullish Pattern:
   A (low) → B (high) → C (low) → Target ↑
   Buy at C, Profit at Target, Stop at C-0.5%

📉 Bearish Pattern:
   A (high) → B (low) → C (high) → Target ↓
   Sell at C, Profit at Target, Stop at C+0.5%
```

---

## ⚙️ Input Parameters Quick Guide

| Input | Default | Adjust | Purpose |
|-------|---------|--------|---------|
| **Enable Trade Signals** | true | ✓ | Turn signals ON/OFF |
| **Bull/Bear SL Mode** | C Level % | ✓ | Choose SL calculation |
| **Bull SL %** | 0.5 | ✓ | % below C (bullish) |
| **Bear SL %** | 0.5 | ✓ | % above C (bearish) |
| **TP Adjustment** | 0.0 | ✓ | Adjust target distance |
| **Override TP** | false | ✓ | Manual TP override |
| **Custom TP Value** | 0.0 | ✓ | Exact TP price |
| **Override SL** | false | ✓ | Manual SL override |
| **Custom SL Value** | 0.0 | ✓ | Exact SL price |
| **Show TP/SL Lines** | true | ✓ | Display on chart |

---

## 📊 Understanding the Signals

### Signal at C Point

**BULLISH (BUY) Alert:**
```
📈 BUY SIGNAL
Entry (C): 211.52          ← Your entry price
Target (TP): 211.62        ← Profit target
Stop Loss (SL): 211.14     ← Risk level
Risk/Reward: 1.5:1         ← Your R:R ratio
```

**BEARISH (SELL) Alert:**
```
📉 SELL SIGNAL
Entry (C): 211.52          ← Your entry price
Target (TP): 211.42        ← Profit target
Stop Loss (SL): 211.90     ← Risk level
Risk/Reward: 2.0:1         ← Your R:R ratio
```

---

## 🎯 Choosing SL Mode

### Mode 1: "C Level %"
```
Bullish: SL = C × (1 - %)
Example: C=100, %=0.5 → SL=99.5

Bearish: SL = C × (1 + %)
Example: C=100, %=0.5 → SL=100.5

✓ Simple and consistent
✓ Easy to adjust
✗ Doesn't use prior patterns
```

### Mode 2: "Prev [Opposite] Target"
```
Bullish: SL = Previous BEAR pattern target
Example: Last bear target=98.5 → SL=98.5

Bearish: SL = Previous BULL pattern target
Example: Last bull target=102.5 → SL=102.5

✓ Uses prior support/resistance
✓ Context-aware
✗ More complex
```

**My Recommendation:** Start with "C Level %", graduate to "Prev Target" once comfortable

---

## 🎮 Configuration Examples

### Conservative Trading (Tight SL)
```
Bull SL %:      0.3          (Tight)
Bear SL %:      0.3          (Tight)
TP Adjustment:  -0.5%        (Below target)
→ Smaller losses, more frequent wins, smaller profits
```

### Balanced Trading (Default)
```
Bull SL %:      0.5          (Medium)
Bear SL %:      0.5          (Medium)
TP Adjustment:  0.0%         (At target)
→ 1:1.5 avg R:R, good balance
```

### Aggressive Trading (Wide SL)
```
Bull SL %:      1.0          (Wide)
Bear SL %:      1.0          (Wide)
TP Adjustment:  +0.5%        (Beyond target)
→ Bigger wins, bigger losses, fewer trades
```

### Dynamic Mode (Using Prev Targets)
```
Bull SL Mode:   "Prev Bear Target"
Bear SL Mode:   "Prev Bull Target"
TP Adjustment:  0.0%
→ Context-aware, respects price structure
```

---

## 🔗 Integration Checklist

- [ ] Indicator loaded on chart
- [ ] ABC labels appearing (A, B, C visible)
- [ ] TP/SL lines showing in correct colors
- [ ] Alert triggered when C forms (check TradingView notifications)
- [ ] Configure TradingView webhook alert
  - [ ] Condition: "📈 BUY at ABC C Level" (BUY)
  - [ ] Condition: "📉 SELL at ABC C Level" (SELL)
  - [ ] Enable Webhook URL: http://localhost:5000/webhook
  - [ ] Header: X-Webhook-Token: <token>
- [ ] Start webhook server: python -m server.webhook_server
- [ ] Start dashboard: streamlit run dashboard/dashboard.py
- [ ] Test: Send manual webhook test
- [ ] Verify: Signal appears in dashboard
- [ ] Confirm: TP/SL prices parsed correctly
- [ ] Ready: Monitor actual alerts

---

## 📈 Quick Status Check

**Indicator working?**
```
✓ ABC labels visible on chart
✓ A, B, C points labeled correctly
✓ Target line drawn (yellow dashed)
→ Indicator is working!
```

**Signals generating?**
```
✓ TradingView notification received
✓ Alert message shows entry, TP, SL
✓ BUY/SELL shown in message
→ Signals are working!
```

**TP/SL correct?**
```
✓ TP line drawn (green for bull, red for bear)
✓ SL line drawn (red for bull, green for bear)
✓ Prices match alert message
→ TP/SL is correct!
```

**Integration working?**
```
✓ Webhook server running (port 5000)
✓ Dashboard receiving signals
✓ Entry/TP/SL logged in database
→ Integration is working!
```

---

## 🔄 Trading Workflow

### Step 1: Wait for Pattern
```
Monitor chart for ABC pattern formation
A → B → C sequence
```

### Step 2: Signal Triggers
```
When C identified → Alert sent
Read: Entry, TP, SL from message
```

### Step 3: Enter Trade
```
In simulated: Auto-logged with TP/SL
In real mode: Order placed to broker
```

### Step 4: Manage Trade
```
Monitor dashboard for order status
Wait for TP or SL hit
Dashboard shows when trade closes
```

### Step 5: Review
```
Log trade result in trading journal
Note if actual price matched TP/SL
Adjust inputs if needed
```

---

## ⚠️ Common Issues

**No patterns showing?**
→ Increase `Pivot Lookback` value (try 15-20)

**TP/SL prices seem wrong?**
→ Check SL Mode matches your intent
→ Verify TP Adjustment setting

**No alerts triggering?**
→ Check "Enable Trade Signals" = true
→ Verify ABC pattern actually forming

**Dashboard not updating?**
→ Confirm webhook server running
→ Check database file exists (logs/trades.db)
→ Restart dashboard (Ctrl+C then rerun)

**Alert message format different?**
→ Manually parse Entry, TP, SL values
→ Update your webhook parsing code

---

## 📞 Quick Help

**"How do I know if SL Mode is working?"**
→ Watch the SL line on chart - should match your chosen mode

**"What's a good R:R ratio to trade?"**
→ Minimum 1:1.5 (risk 1 to make 1.5)
→ Sweet spot: 1:2 or better

**"How often do signals trigger?"**
→ 1-3 times per week per symbol (depends on timeframe)
→ Fewer signals = higher quality (usually)

**"Can I trade multiple ABC patterns at once?"**
→ Yes! Each pattern generates separate signal
→ Track them separately in your system

**"Should I use "C Level %" or "Prev Target" mode?"**
→ Start: "C Level %" (simpler)
→ Improve: "Prev Target" (context-aware)

---

## 📚 More Info

**For detailed guide:** Read `INDICATOR_GUIDE.md`

**For integration:** Read `TRADING_SYSTEM_INTEGRATION.md`

**For full summary:** Read `IMPLEMENTATION_SUMMARY.md`

---

## 🎯 Your Next Step

Choose ONE:

**A) Test on Chart First**
1. Load indicator
2. Set inputs to default
3. Wait for ABC pattern
4. Watch TP/SL line positions
5. Check alert message format

**B) Integrate Immediately**
1. Setup webhook alert in TradingView
2. Start webhook server
3. Send test signal
4. Verify dashboard receives it
5. Monitor a real signal

**C) Deep Dive**
1. Read `INDICATOR_GUIDE.md`
2. Read `TRADING_SYSTEM_INTEGRATION.md`
3. Understand all parameters
4. Plan your configuration
5. Then execute A or B

---

**⏱️ Time to Get Started: 5 Minutes**
**Complexity: Medium (but well documented)**
**Risk: Start with simulated mode first!**

---

**Version:** 2.0
**Last Updated:** 2026-03-16
**Status:** ✅ Ready to Use
