# A+ Gold EA - Usage Guide

## Overview
This Expert Advisor implements a sophisticated XAUUSD (Gold) trading strategy optimized for prop firm funded account challenges. It uses high-confluence entry signals combining trend analysis, price action patterns, and Fibonacci retracements.

---

## Installation

1. **Copy the EA file:**
   - Copy `A_Plus_Gold_EA.mq5` to your MetaTrader 5 `MQL5/Experts` folder
   - Path: `C:\Users\[YourName]\AppData\Roaming\MetaTrader 5\MQL5\Experts\`

2. **Compile the EA:**
   - Open MetaEditor (F4 in MT5)
   - Open `A_Plus_Gold_EA.mq5`
   - Click "Compile" (F7) or press F7
   - Ensure you see "0 error(s), 0 warning(s)" in the compile log

3. **Attach to chart:**
   - In MT5, open a chart for XAUUSD
   - Drag the EA from Navigator panel onto the chart
   - Configure parameters in the EA settings dialog
   - Enable "AutoTrading" (button in toolbar)

---

## Recommended Settings

### Timeframes
- **Chart Timeframe:** M15 (for entry signals)
- **Trend Filter:** H1 (automatically analyzed)
- The EA works on M15 but uses H1 for trend confirmation

### Default Parameters (Prop Firm Optimized)

#### Trading Settings
- **Risk per trade:** 1.0% (adjust based on account size and prop firm rules)
- **Risk:Reward Ratio:** 3.0 (1:3)
- **Partial TP:** 50% at 1:2R
- **Magic Number:** 123456 (change if running multiple EAs)

#### Trend Filter
- **Trend Timeframe:** H1
- **Fast EMA:** 20
- **Slow EMA:** 50

#### Entry Signals
- **Entry Timeframe:** M15
- **Fibonacci Retracement:** 0.618 (61.8%)
- **Fib Tolerance:** 30 points
- **Require Engulfing:** Yes

#### Risk Management
- **Min Stop Loss:** 50 points
- **Break-Even:** Enabled (trigger at 1.0R)
- **Trailing Stop:** Enabled (start at 1.5R, step 0.3R)

#### Prop Firm Safety Rules
- **Max Daily Loss:** 5.0%
- **Max Weekly Loss:** 10.0%
- **Max Total Drawdown:** 12.0%
- **Max Consecutive Losses:** 3
- **Max Trades Per Day:** 5
- **Session Filter:** Enabled (UTC 07:00-20:00)
- **Equity Protection:** Enabled

---

## Strategy Logic

### Entry Conditions (ALL must be met):
1. **Trend Filter:**
   - H1 EMA(20) > EMA(50) for BUY signals
   - H1 EMA(20) < EMA(50) for SELL signals

2. **Engulfing Candle:**
   - Bullish engulfing for BUY (previous bearish, current bullish and engulfs)
   - Bearish engulfing for SELL (previous bullish, current bearish and engulfs)

3. **Fibonacci Retracement:**
   - Price near 0.618 Fib level of recent swing (±30 points tolerance)
   - For BUY: Retracement from swing high
   - For SELL: Retracement from swing low

### Trade Management:
- **Stop Loss:** Recent swing high/low or minimum 50 points
- **Take Profit:** 1:3 Risk:Reward ratio
- **Partial TP:** 50% closes at 1:2R, remaining 50% runs to 1:3R
- **Break-Even:** SL moved to entry after 1.0R profit
- **Trailing Stop:** Activates after 1.5R profit, trails by 0.3R steps

---

## Backtesting

### Setup:
1. Open Strategy Tester (Ctrl+R)
2. Select Expert Advisor: `A_Plus_Gold_EA`
3. Select Symbol: `XAUUSD`
4. Period: M15
5. Date Range: At least 1-3 months (recommended: 3-6 months)
6. Model: "Every tick" or "1 minute OHLC" (faster but less accurate)

### Recommended Settings:
- **Deposit:** Match your prop firm account size
- **Leverage:** 1:100 (standard for prop firms)
- **Spread:** Use current spread (typically 20-30 points for XAUUSD)
- **Execution Mode:** "Real ticks" for most accurate results

### Evaluating Results:
- **Profit Factor:** > 1.5
- **Win Rate:** 40-60% (acceptable with 1:3 R:R)
- **Max Drawdown:** < 12%
- **Expected Monthly Return:** 8-15% (for prop firm targets)
- **Sharpe Ratio:** > 1.0

---

## Monitoring & Logs

### On-Chart Panel
The EA displays a real-time info panel showing:
- **Balance & Equity:** Current account values
- **Drawdown:** Current drawdown percentage (red if > 80% of limit)
- **Daily P/L:** Today's profit/loss percentage
- **Open Trades:** Number of active positions
- **Risk per Trade:** Current risk setting
- **Trend Direction:** BULLISH/BEARISH/NEUTRAL
- **Win Rate:** Overall win rate with win/loss count

### Expert Logs (F12 or View → Terminal → Experts)
The EA logs all important actions:
- Entry signals and trade executions
- Stop loss and take profit levels
- Partial TP closures
- Break-even moves
- Trailing stop updates
- Safety rule breaches
- Daily/weekly resets

### Key Log Messages:
- `"BUY order executed: Lots=X SL=Y TP=Z"` - New buy trade
- `"SELL order executed: Lots=X SL=Y TP=Z"` - New sell trade
- `"Partial TP executed: 50% at 1:2R"` - Partial profit taken
- `"Break-even moved to entry price"` - SL moved to BE
- `"Trailing stop updated to: X"` - Trailing stop adjusted
- `"Daily loss limit breached"` - Trading disabled for day
- `"Max consecutive losses reached"` - Trading paused

---

## Prop Firm Compliance

### Safety Features:
1. **Daily Loss Limit:** Trading stops if daily loss exceeds 5%
2. **Weekly Loss Limit:** Trading stops if weekly loss exceeds 10%
3. **Total Drawdown:** Trading stops if drawdown exceeds 12%
4. **Consecutive Losses:** Trading stops after 3 consecutive losses
5. **Trade Limits:** Maximum 5 trades per day
6. **Session Filter:** Only trades during London-NY overlap (UTC 07:00-20:00)
7. **Equity Protection:** Auto-closes all trades if drawdown limit breached

### Important Notes:
- **No Grid Trading:** EA only opens one position at a time
- **No Martingale:** Lot size based on fixed risk %, not previous losses
- **No Pyramiding:** Only one position per direction
- **No News Trading:** Placeholder for news filter (currently disabled)

---

## Troubleshooting

### EA Not Trading:
1. Check "AutoTrading" is enabled (green button in toolbar)
2. Verify symbol is XAUUSD
3. Check if safety rules are blocking trades:
   - Daily/weekly loss limits
   - Max trades per day reached
   - Consecutive losses limit
   - Drawdown limit
4. Verify session filter timing (UTC 07:00-20:00)
5. Check trend direction (may be neutral)

### Compilation Errors:
- Ensure MT5 Build ≥ 3900
- Check all required includes are present
- Verify no syntax errors in code

### Trading Issues:
- **"Invalid lot size":** Check broker's minimum lot size
- **"Invalid stop loss":** EA adjusts automatically, but verify minimum SL distance
- **"Not enough money":** Reduce RiskPerTrade parameter

### Performance Issues:
- If EA is slow, reduce indicator calculations
- Close unnecessary charts
- Use VPS for 24/7 operation

---

## Optimization Tips

### For Prop Firm Challenges:
1. **Start Conservative:**
   - Risk: 0.5-1.0% per trade
   - Max trades: 3-5 per day
   - Focus on quality over quantity

2. **Monitor Daily:**
   - Check daily P/L each morning
   - Review trades in journal
   - Adjust if nearing limits

3. **Account for Spread:**
   - XAUUSD spreads can be 20-50 points
   - Ensure minimum SL accounts for spread
   - Consider broker with tighter spreads

4. **Time Management:**
   - EA only trades during London-NY overlap
   - Ensure VPS/server is in correct timezone
   - Verify UTC time settings

### Parameter Tuning:
- **RiskPerTrade:** Start at 1%, increase to 1.5-2% if comfortable
- **R:R Ratio:** Can reduce to 1:2.5 if not enough trades
- **Fib Tolerance:** Increase to 40-50 points for more signals
- **Session Hours:** Adjust based on your timezone and market hours

---

## Important Disclaimers

⚠️ **RISK WARNING:**
- Trading involves substantial risk of loss
- Past performance does not guarantee future results
- This EA is a tool, not a guarantee of profits
- Always test thoroughly before live trading
- Start with minimum risk and scale gradually

📋 **PROP FIRM NOTES:**
- Each prop firm has different rules
- Verify all parameters match your prop firm's requirements
- Some firms may restrict certain EA features
- Always read and comply with prop firm terms

---

## Support & Updates

### Code Structure:
- Modular design for easy customization
- Clear function separation
- Comprehensive error handling
- Detailed logging for debugging

### Future Enhancements (Placeholder):
- DXY correlation filter
- News impact filter
- Advanced Fib calculations
- Multi-timeframe analysis
- Performance analytics dashboard

---

## Quick Reference Card

| Setting | Default | Purpose |
|---------|---------|---------|
| RiskPerTrade | 1.0% | Risk per trade |
| RiskRewardRatio | 3.0 | TP:SL ratio |
| MaxDailyLoss | 5.0% | Daily stop loss |
| MaxDrawdown | 12.0% | Total drawdown limit |
| MaxTradesPerDay | 5 | Trade frequency limit |
| Session Hours | 07:00-20:00 UTC | Trading window |

---

**Version:** 1.00  
**Last Updated:** 2024  
**Compatibility:** MT5 Build ≥ 3900  
**Symbol:** XAUUSD (Gold)  
**Timeframes:** M15 (entries), H1 (trend)

---

**Happy Trading! 🚀**
