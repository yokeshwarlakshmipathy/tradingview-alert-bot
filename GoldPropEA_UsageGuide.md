# Gold Prop Firm EA - Complete Usage Guide

## 📋 Overview
The **Gold Prop Firm EA** is a professional-grade MetaTrader 5 Expert Advisor designed specifically for passing prop firm challenges on XAUUSD (Gold). It implements a high-probability, low-frequency trading strategy with strict risk management and safety protocols.

---

## 🎯 Strategy Summary

### Core Logic
- **Market Bias**: Determined by EMA(20) vs EMA(50) on H1/H4 timeframe
- **Entry Trigger**: Engulfing candle pattern on M15 timeframe
- **Confluence Filter**: Price must be near 0.618 Fibonacci retracement of recent swing
- **Risk:Reward**: Default 1:3 with partial profit taking at 1:2

### Trading Style
- **Type**: Swing to intraday
- **Frequency**: 1-5 high-quality setups per day
- **Approach**: "A+ setup only" - quality over quantity
- **Sessions**: London-New York overlap (UTC 07:00-20:00)

---

## 🚀 Installation & Setup

### Step 1: Installation
1. Download `GoldPropFirmEA.mq5`
2. Open MetaTrader 5
3. Go to: **File → Open Data Folder → MQL5 → Experts**
4. Copy the `.mq5` file to the Experts folder
5. Restart MT5 or click "Refresh" in the Navigator panel

### Step 2: Compilation
1. Open MetaEditor (F4 in MT5)
2. Open `GoldPropFirmEA.mq5`
3. Click **Compile** (F7)
4. Verify: **0 errors, 0 warnings**

### Step 3: Chart Setup
1. Open an XAUUSD chart
2. Set timeframe to **M15** (entry timeframe)
3. Drag the EA from Navigator onto the chart
4. Check "Allow Algo Trading" and "Allow DLL imports"
5. Configure parameters (see below)
6. Click OK

---

## ⚙️ Recommended Parameter Settings

### For $100,000 Prop Challenge (8% target in 1 week)

```
=== STRATEGY SETTINGS ===
AllowedSymbol = "XAUUSD"
TrendTimeframe = PERIOD_H1
EntryTimeframe = PERIOD_M15
EMA_Fast = 20
EMA_Slow = 50

=== ENTRY FILTERS ===
UseEngulfingFilter = true
UseFibonacciFilter = true
FibLevel = 0.618
FibTolerancePoints = 100
MinEngulfingBodyPoints = 50

=== RISK MANAGEMENT ===
RiskPerTrade = 1.0%           // Conservative: 0.5-1.0%, Aggressive: 1.5-2.0%
RiskRewardRatio = 3.0
MinStopLossPips = 150
MaxStopLossPips = 500
UsePartialTP = true
PartialTPPercent = 50.0
PartialTPRatio = 2.0

=== TRADE MANAGEMENT ===
UseBreakEven = true
BreakEvenRatio = 1.0
BreakEvenPlusPips = 10
UseTrailingStop = true
TrailingStartRatio = 1.5
TrailingStopPips = 200
TrailingStepPips = 50

=== PROP FIRM SAFETY ===
MaxDailyLossPercent = 5.0%    // Adjust to your prop firm rules
MaxWeeklyLossPercent = 8.0%   // Adjust to your prop firm rules
MaxTotalDrawdownPercent = 10.0%
MaxConsecutiveLosses = 3
MaxTradesPerDay = 5
EnableDailyReset = true

=== SESSION FILTERS ===
UseSessionFilter = true
SessionStartHour = 7          // UTC 07:00 (London open)
SessionEndHour = 20           // UTC 20:00 (NY close)
AvoidNews = true

=== DASHBOARD & LOGGING ===
ShowDashboard = true
VerboseLogging = true
MagicNumber = 123456
CommentPrefix = "GoldPropEA"
```

### For Smaller Accounts ($10k-$25k)
- `RiskPerTrade = 0.5-1.0%`
- `MaxDailyLossPercent = 3.0%`
- `MaxTradesPerDay = 3`

---

## 📊 Backtesting Guide

### Setup
1. Open MT5 Strategy Tester (Ctrl+R)
2. Select `GoldPropFirmEA.mq5`
3. Symbol: **XAUUSD**
4. Period: **M15** (entry timeframe)
5. Date Range: Last 6-12 months
6. Execution Delay: 0
7. Initial Deposit: Match your prop challenge amount

### Optimization Tips
1. **Don't over-optimize** - avoid curve fitting
2. Test on out-of-sample data
3. Focus on these metrics:
   - Win rate: Target 45-60%
   - Profit factor: > 1.5
   - Max drawdown: < 10%
   - Recovery factor: > 3.0
   - Average R:R: > 2.0

### Recommended Test Period
- **Training Period**: 6 months
- **Validation Period**: 3 months (out-of-sample)
- **Minimum Trades**: 50+ for statistical significance

---

## 📈 Live Trading Checklist

### Before Going Live
- [ ] Backtested successfully with positive results
- [ ] Forward tested on demo for 1-2 weeks
- [ ] Verified prop firm rules match EA settings
- [ ] Checked broker spread and commission costs
- [ ] Ensured stable VPS or reliable computer
- [ ] Confirmed MT5 is connected and trades allowed
- [ ] Dashboard displays correctly
- [ ] Logs are working

### Daily Routine
1. **Morning** (before London session)
   - Check economic calendar for high-impact news
   - Review EA dashboard
   - Verify EA is running (smile icon on chart)
   
2. **During Session**
   - Monitor dashboard periodically
   - Don't interfere with EA trades
   - Check terminal logs if issues arise
   
3. **Evening** (after NY close)
   - Review daily performance
   - Check logs for any errors
   - Note daily P/L percentage

---

## 🎛️ Understanding the Dashboard

The on-chart dashboard displays real-time stats:

```
═══ GOLD PROP EA ═══
Balance: $100,000.00        // Current account balance
Equity: $100,500.00         // Current equity (balance + floating P/L)
Drawdown: 0.50%             // Current drawdown from peak

─────────────────────
Daily P/L: $500.00          // Today's profit/loss in dollars
Daily %: 0.50%              // Today's profit/loss percentage
Trades Today: 2/5           // Trades executed / max allowed

─────────────────────
Open Positions: 1           // Currently open trades
Risk/Trade: 1.00%           // Risk percentage per trade
Trend: BULLISH              // Current market trend (H1)

─────────────────────
Wins: 5 | Losses: 1         // Daily win/loss count
Status: ACTIVE              // Trading status (ACTIVE/DISABLED)
```

### Status Indicators
- **ACTIVE** = EA is trading normally
- **DISABLED** = EA stopped due to safety rule violation

---

## 🔍 Interpreting Logs

### Entry Signals
```
🟢 BUY SIGNAL: Trend=Bullish | Engulfing=Yes | Fib=Yes
✅ BUY ORDER OPENED: Lot=0.10 | Entry=2025.50 | SL=2020.00 | TP=2042.00 | R:R=1:3.0
```

### Trade Management
```
🔒 Break-Even activated for #12345 | New SL=2025.50
💰 Partial TP executed for #12345 | Closed 50% at 2.0R
📈 Trailing Stop updated for #12345 | New SL=2030.00
```

### Safety Alerts
```
⚠️ Prop firm safety check failed - trading disabled
🚨 DAILY LOSS LIMIT REACHED: -5.00%
🚨 MAX CONSECUTIVE LOSSES REACHED: 3
```

### Daily Reset
```
═══════════════════════════════════════════════════════════
🔄 DAILY RESET
═══════════════════════════════════════════════════════════
📊 Previous Day Summary:
   - Trades: 3
   - Wins: 2
   - Losses: 1
   - P/L: $1,200.00 (1.20%)
═══════════════════════════════════════════════════════════
```

---

## ⚠️ Prop Firm Safety Features

### Automatic Protection
The EA will **automatically stop trading** if:
1. Daily loss reaches limit (default: -5%)
2. Weekly loss reaches limit (default: -8%)
3. Total drawdown exceeds limit (default: -10%)
4. Consecutive losses hit maximum (default: 3)
5. Max trades per day reached (default: 5)

### Manual Intervention
You can manually disable the EA by:
- Removing it from the chart
- Clicking "Remove Expert" in chart context menu
- Pressing the "AutoTrading" button in MT5 toolbar

### Emergency Close
The EA automatically closes ALL positions when:
- Daily/weekly loss limit is breached
- Max drawdown is exceeded

---

## 🛠️ Troubleshooting

### EA Not Trading
**Check:**
- [ ] AutoTrading enabled (green button in toolbar)
- [ ] EA has smile icon (not sad face) on chart
- [ ] Within trading session (07:00-20:00 UTC)
- [ ] No safety limits reached (check dashboard status)
- [ ] Sufficient margin available
- [ ] Symbol is XAUUSD

### Orders Not Opening
**Common Causes:**
1. **Invalid stops** - broker has minimum distance requirements
2. **Insufficient margin** - reduce lot size
3. **Market closed** - outside trading hours
4. **No signal** - waiting for A+ setup
5. **Daily limit reached** - max trades hit

**Solution:**
- Check terminal logs for error messages
- Verify broker allows trading on XAUUSD
- Check "Journal" tab for detailed errors

### Dashboard Not Showing
1. Re-attach EA to chart
2. Check `ShowDashboard = true` in settings
3. Maximize chart window
4. Change chart background color for visibility

### Unexpected Behavior
1. Check MT5 version (minimum build 3900)
2. Recompile EA in MetaEditor
3. Remove and re-attach to chart
4. Check for conflicting EAs on same symbol

---

## 📊 Performance Expectations

### Realistic Targets (1-week challenge)
- **Target**: 6-10% profit
- **Win Rate**: 50-65%
- **Trades/Week**: 5-15 (high selectivity)
- **Average R:R**: 2.0-3.0
- **Max Drawdown**: < 5%

### Risk of Ruin
With proper settings:
- Risk per trade: 1%
- Max daily loss: 5%
- Risk of ruin: < 1% (very safe)

### Monthly Performance (Estimate)
- **Conservative** (0.5% risk): 8-15% per month
- **Moderate** (1.0% risk): 15-25% per month
- **Aggressive** (2.0% risk): 25-40% per month (higher risk)

---

## 🎓 Best Practices

### Do's ✅
- Let the EA run uninterrupted during session hours
- Monitor daily performance
- Adjust risk per trade based on challenge size
- Use VPS for 24/7 uptime
- Keep detailed records of performance
- Start with demo account first
- Trust the strategy during drawdown periods

### Don'ts ❌
- Don't manually close EA trades
- Don't override EA settings mid-challenge
- Don't run multiple EAs on same symbol
- Don't trade during major news if AvoidNews=true
- Don't increase risk after losses (revenge trading)
- Don't panic during normal drawdown (< 5%)
- Don't expect 100% win rate

---

## 🔧 Advanced Customization

### Aggressive Mode (Faster profit, higher risk)
```
RiskPerTrade = 2.0%
MaxTradesPerDay = 8
MaxDailyLossPercent = 8.0%
```

### Conservative Mode (Safer, slower)
```
RiskPerTrade = 0.5%
MaxTradesPerDay = 3
MaxDailyLossPercent = 3.0%
```

### News-Aware Mode
Set `AvoidNews = true` and manually disable EA 30 minutes before/after:
- NFP (Non-Farm Payrolls)
- FOMC announcements
- CPI releases
- Interest rate decisions

---

## 📞 Support & FAQ

### Why is the EA not taking trades?
**Answer**: The EA is highly selective. It only trades "A+ setups" with all filters aligned:
- Trend confirmation (EMA alignment)
- Engulfing candle pattern
- Price near Fibonacci level
- Within trading session
- No safety limits breached

Average: 1-3 setups per day is normal.

### Can I use on other symbols?
**Answer**: The EA is optimized for XAUUSD. It may work on other volatile pairs (GBPUSD, EURUSD) but requires re-optimization of parameters.

### What broker is recommended?
**Answer**: Use a broker with:
- Low spreads on Gold (< 20 points)
- Fast execution (< 50ms)
- No requotes
- ECN or STP model
- Good reputation with prop firms

### Can I run multiple instances?
**Answer**: Yes, but:
- Use different magic numbers
- Different symbols OR
- Different timeframes/strategies
- Monitor total risk across all instances

---

## 📄 License & Disclaimer

**License**: This EA is provided for educational and trading purposes.

**Disclaimer**: 
- Trading involves substantial risk of loss
- Past performance does not guarantee future results
- Use at your own risk
- Author is not responsible for any losses
- Always test thoroughly before live trading
- Ensure compliance with your prop firm's rules

---

## 🎯 Quick Start Summary

1. **Install** → Copy to MQL5/Experts folder
2. **Compile** → 0 errors, 0 warnings
3. **Backtest** → Verify positive results
4. **Demo Test** → 1-2 weeks forward testing
5. **Configure** → Set risk parameters
6. **Go Live** → Attach to XAUUSD M15 chart
7. **Monitor** → Check dashboard daily
8. **Succeed** → Pass your prop challenge!

---

## 📚 Additional Resources

### Recommended Reading
- "Trade Your Way to Financial Freedom" - Van Tharp
- "The New Trading for a Living" - Alexander Elder
- Study EMA crossover strategies
- Learn Fibonacci retracement theory

### MT5 Resources
- Official MQL5 Documentation: mql5.com/en/docs
- MT5 User Guide: MetaQuotes website
- Community: mql5.com/en/forum

---

**Good luck with your prop firm challenge! Trade smart, manage risk, and let the EA do its work.** 🚀📈

---

**Version**: 1.00  
**Last Updated**: 2025-11-05  
**Compatible with**: MT5 Build 3900+
