//+------------------------------------------------------------------+
//|                                              GoldPropFirmEA.mq5  |
//|                        Professional Gold Trading EA for Prop Firms |
//|                                    Expert MQL5 Development Team   |
//+------------------------------------------------------------------+
#property copyright "Expert MQL5 Development Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description "A+ Gold Trading Strategy - Prop Firm Challenge Optimized"
#property description "Implements trend filtering, confluence entries, strict risk management"

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Strategy Parameters
input group "=== STRATEGY SETTINGS ==="
input string   AllowedSymbol = "XAUUSD";              // Trading Symbol
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H1;     // Trend Filter Timeframe (H1/H4)
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_M15;    // Entry Signal Timeframe
input int      EMA_Fast = 20;                         // Fast EMA Period
input int      EMA_Slow = 50;                         // Slow EMA Period

//--- Entry Filters
input group "=== ENTRY FILTERS ==="
input bool     UseEngulfingFilter = true;             // Use Engulfing Candle Filter
input bool     UseFibonacciFilter = true;             // Use Fibonacci Retracement Filter
input double   FibLevel = 0.618;                      // Fibonacci Retracement Level
input int      FibTolerancePoints = 100;              // Fib Level Tolerance (Points)
input int      MinEngulfingBodyPoints = 50;           // Min Engulfing Body Size (Points)

//--- Risk & Money Management
input group "=== RISK MANAGEMENT ==="
input double   RiskPerTrade = 1.0;                    // Risk Per Trade (% of Balance)
input double   RiskRewardRatio = 3.0;                 // Take Profit Risk:Reward Ratio
input int      MinStopLossPips = 150;                 // Minimum Stop Loss (Pips)
input int      MaxStopLossPips = 500;                 // Maximum Stop Loss (Pips)
input bool     UsePartialTP = true;                   // Use Partial Take Profit
input double   PartialTPPercent = 50.0;               // Partial TP Close % at 2R
input double   PartialTPRatio = 2.0;                  // Partial TP at R:R Ratio

//--- Trailing Stop & Break-Even
input group "=== TRADE MANAGEMENT ==="
input bool     UseBreakEven = true;                   // Move to Break-Even
input double   BreakEvenRatio = 1.0;                  // Break-Even at R:R
input int      BreakEvenPlusPips = 10;                // Break-Even + Pips
input bool     UseTrailingStop = true;                // Use Trailing Stop
input double   TrailingStartRatio = 1.5;              // Trailing Start at R:R
input int      TrailingStopPips = 200;                // Trailing Stop Distance (Pips)
input int      TrailingStepPips = 50;                 // Trailing Step (Pips)

//--- Prop Firm Safety Rules
input group "=== PROP FIRM SAFETY ==="
input double   MaxDailyLossPercent = 5.0;             // Max Daily Loss (%)
input double   MaxWeeklyLossPercent = 8.0;            // Max Weekly Loss (%)
input double   MaxTotalDrawdownPercent = 10.0;        // Max Total Drawdown (%)
input int      MaxConsecutiveLosses = 3;              // Max Consecutive Losses
input int      MaxTradesPerDay = 5;                   // Max Trades Per Day
input bool     EnableDailyReset = true;               // Enable Daily Reset at 00:00 UTC

//--- Session & Time Filters
input group "=== SESSION FILTERS ==="
input bool     UseSessionFilter = true;               // Use Trading Session Filter
input int      SessionStartHour = 7;                  // Session Start (UTC Hour)
input int      SessionEndHour = 20;                   // Session End (UTC Hour)
input bool     AvoidNews = true;                      // Avoid High-Impact News (Placeholder)

//--- Display & Logging
input group "=== DASHBOARD & LOGGING ==="
input bool     ShowDashboard = true;                  // Show On-Chart Dashboard
input bool     VerboseLogging = true;                 // Enable Detailed Logging
input int      MagicNumber = 123456;                  // EA Magic Number
input string   CommentPrefix = "GoldPropEA";          // Order Comment Prefix

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+

//--- Trading objects
CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;
CSymbolInfo    symbolInfo;

//--- Indicator handles
int            handleEMA_Fast_Trend;
int            handleEMA_Slow_Trend;

//--- Buffers for indicator values
double         emaFastTrend[];
double         emaSlowTrend[];

//--- Trading state variables
datetime       lastBarTime = 0;
datetime       dailyResetTime = 0;
datetime       weeklyResetTime = 0;

//--- Daily tracking
double         dailyStartBalance = 0;
double         dailyProfitLoss = 0;
int            dailyTradeCount = 0;
int            dailyWins = 0;
int            dailyLosses = 0;

//--- Weekly tracking
double         weeklyStartBalance = 0;
double         weeklyProfitLoss = 0;

//--- Risk tracking
int            consecutiveLosses = 0;
double         initialBalance = 0;
double         peakBalance = 0;

//--- Trading flags
bool           tradingEnabled = true;
bool           dailyLimitReached = false;

//--- Swing tracking for Fibonacci
double         lastSwingHigh = 0;
double         lastSwingLow = 0;
datetime       lastSwingHighTime = 0;
datetime       lastSwingLowTime = 0;

//--- Dashboard object name
string         dashboardName = "EA_Dashboard";

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   //--- Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
   {
      Print("❌ ERROR: Failed to initialize symbol info for ", _Symbol);
      return INIT_FAILED;
   }
   symbolInfo.Refresh();
   
   //--- Check if we're on the correct symbol
   if(StringFind(_Symbol, AllowedSymbol) == -1)
   {
      Print("⚠️ WARNING: EA designed for ", AllowedSymbol, " but attached to ", _Symbol);
   }
   
   //--- Initialize trend EMA indicators
   handleEMA_Fast_Trend = iMA(_Symbol, TrendTimeframe, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Slow_Trend = iMA(_Symbol, TrendTimeframe, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handleEMA_Fast_Trend == INVALID_HANDLE || handleEMA_Slow_Trend == INVALID_HANDLE)
   {
      Print("❌ ERROR: Failed to create EMA indicator handles");
      return INIT_FAILED;
   }
   
   //--- Set array as series
   ArraySetAsSeries(emaFastTrend, true);
   ArraySetAsSeries(emaSlowTrend, true);
   
   //--- Initialize balance tracking
   initialBalance = account.Balance();
   peakBalance = initialBalance;
   dailyStartBalance = initialBalance;
   weeklyStartBalance = initialBalance;
   
   //--- Initialize time tracking
   MqlDateTime dtStruct;
   TimeToStruct(TimeCurrent(), dtStruct);
   dtStruct.hour = 0;
   dtStruct.min = 0;
   dtStruct.sec = 0;
   dailyResetTime = StructToTime(dtStruct);
   
   //--- Calculate week start
   int dayOfWeek = dtStruct.day_of_week;
   int daysToMonday = (dayOfWeek == 0) ? 6 : dayOfWeek - 1;
   weeklyResetTime = dailyResetTime - daysToMonday * 86400;
   
   //--- Print initialization info
   Print("═══════════════════════════════════════════════════════════");
   Print("✅ Gold Prop Firm EA Initialized Successfully");
   Print("═══════════════════════════════════════════════════════════");
   Print("📊 Symbol: ", _Symbol);
   Print("💰 Initial Balance: $", DoubleToString(initialBalance, 2));
   Print("📈 Trend TF: ", EnumToString(TrendTimeframe));
   Print("🎯 Entry TF: ", EnumToString(EntryTimeframe));
   Print("⚠️ Risk Per Trade: ", DoubleToString(RiskPerTrade, 2), "%");
   Print("🎲 Magic Number: ", MagicNumber);
   Print("═══════════════════════════════════════════════════════════");
   
   //--- Create dashboard
   if(ShowDashboard)
      CreateDashboard();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(handleEMA_Fast_Trend != INVALID_HANDLE)
      IndicatorRelease(handleEMA_Fast_Trend);
   if(handleEMA_Slow_Trend != INVALID_HANDLE)
      IndicatorRelease(handleEMA_Slow_Trend);
   
   //--- Remove dashboard
   ObjectDelete(0, dashboardName);
   
   //--- Print deinitialization info
   Print("═══════════════════════════════════════════════════════════");
   Print("🛑 Gold Prop Firm EA Deinitialized");
   Print("═══════════════════════════════════════════════════════════");
   Print("💰 Final Balance: $", DoubleToString(account.Balance(), 2));
   Print("📊 Total P/L: $", DoubleToString(account.Balance() - initialBalance, 2));
   Print("📈 Peak Balance: $", DoubleToString(peakBalance, 2));
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for daily reset
   CheckDailyReset();
   
   //--- Update dashboard
   if(ShowDashboard)
      UpdateDashboard();
   
   //--- Check prop firm safety rules
   if(!CheckPropFirmSafety())
   {
      if(VerboseLogging)
         Print("⚠️ Prop firm safety check failed - trading disabled");
      return;
   }
   
   //--- Check session filter
   if(UseSessionFilter && !IsWithinTradingSession())
   {
      return; // Outside trading hours
   }
   
   //--- Check for new bar on entry timeframe
   if(!IsNewBar(EntryTimeframe))
      return;
   
   //--- Update indicator buffers
   if(!UpdateIndicators())
   {
      if(VerboseLogging)
         Print("⚠️ Failed to update indicators");
      return;
   }
   
   //--- Update swing points for Fibonacci
   UpdateSwingPoints();
   
   //--- Manage open positions
   ManageOpenPositions();
   
   //--- Check if we can open new trades
   if(dailyTradeCount >= MaxTradesPerDay)
   {
      if(VerboseLogging)
         Print("⚠️ Max trades per day reached: ", dailyTradeCount, "/", MaxTradesPerDay);
      return;
   }
   
   //--- Don't open new position if one already exists
   if(CountOpenPositions() > 0)
      return;
   
   //--- Check for entry signals
   int signal = GetEntrySignal();
   
   if(signal == 1) // Buy signal
   {
      ExecuteBuyOrder();
   }
   else if(signal == -1) // Sell signal
   {
      ExecuteSellOrder();
   }
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                       |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe)
{
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Update indicator values                                           |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   //--- Copy EMA values
   if(CopyBuffer(handleEMA_Fast_Trend, 0, 0, 3, emaFastTrend) <= 0)
      return false;
   
   if(CopyBuffer(handleEMA_Slow_Trend, 0, 0, 3, emaSlowTrend) <= 0)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Determine market trend                                            |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
   //--- Get current EMA values from trend timeframe
   double emaFast = emaFastTrend[0];
   double emaSlow = emaSlowTrend[0];
   
   //--- Bullish trend: EMA20 > EMA50
   if(emaFast > emaSlow)
      return 1;
   
   //--- Bearish trend: EMA20 < EMA50
   if(emaFast < emaSlow)
      return -1;
   
   //--- No clear trend
   return 0;
}

//+------------------------------------------------------------------+
//| Check for engulfing candle pattern                                |
//+------------------------------------------------------------------+
bool IsEngulfingCandle(bool bullish)
{
   if(!UseEngulfingFilter)
      return true; // Filter disabled, always pass
   
   //--- Get last 2 candles on entry timeframe
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, EntryTimeframe, 0, 3, rates) < 3)
      return false;
   
   //--- Current candle (index 1 = last closed candle)
   double currentOpen = rates[1].open;
   double currentClose = rates[1].close;
   double currentBody = MathAbs(currentClose - currentOpen);
   
   //--- Previous candle (index 2)
   double prevOpen = rates[2].open;
   double prevClose = rates[2].close;
   double prevBody = MathAbs(prevClose - prevOpen);
   
   //--- Convert minimum body size to price
   double minBodySize = MinEngulfingBodyPoints * _Point;
   
   if(bullish)
   {
      //--- Bullish engulfing: current candle is bullish and engulfs previous bearish candle
      bool isBullishCandle = (currentClose > currentOpen);
      bool prevBearishCandle = (prevClose < prevOpen);
      bool engulfs = (currentOpen <= prevClose && currentClose > prevOpen);
      bool bodyLargeEnough = (currentBody >= minBodySize);
      
      return (isBullishCandle && prevBearishCandle && engulfs && bodyLargeEnough);
   }
   else
   {
      //--- Bearish engulfing: current candle is bearish and engulfs previous bullish candle
      bool isBearishCandle = (currentClose < currentOpen);
      bool prevBullishCandle = (prevClose > prevOpen);
      bool engulfs = (currentOpen >= prevClose && currentClose < prevOpen);
      bool bodyLargeEnough = (currentBody >= minBodySize);
      
      return (isBearishCandle && prevBullishCandle && engulfs && bodyLargeEnough);
   }
}

//+------------------------------------------------------------------+
//| Update swing high/low points                                      |
//+------------------------------------------------------------------+
void UpdateSwingPoints()
{
   //--- Get recent price data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int bars = 100; // Look back period
   if(CopyRates(_Symbol, EntryTimeframe, 0, bars, rates) < bars)
      return;
   
   //--- Find swing high (peak with lower highs on both sides)
   for(int i = 5; i < bars - 5; i++)
   {
      bool isSwingHigh = true;
      
      for(int j = 1; j <= 5; j++)
      {
         if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh && rates[i].time > lastSwingHighTime)
      {
         lastSwingHigh = rates[i].high;
         lastSwingHighTime = rates[i].time;
         break;
      }
   }
   
   //--- Find swing low (trough with higher lows on both sides)
   for(int i = 5; i < bars - 5; i++)
   {
      bool isSwingLow = true;
      
      for(int j = 1; j <= 5; j++)
      {
         if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow && rates[i].time > lastSwingLowTime)
      {
         lastSwingLow = rates[i].low;
         lastSwingLowTime = rates[i].time;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price is near Fibonacci retracement level                |
//+------------------------------------------------------------------+
bool IsNearFibonacciLevel(bool forBuy)
{
   if(!UseFibonacciFilter)
      return true; // Filter disabled, always pass
   
   //--- Need valid swing points
   if(lastSwingHigh == 0 || lastSwingLow == 0)
      return true; // Can't calculate, pass the filter
   
   double currentPrice = (forBuy ? symbolInfo.Ask() : symbolInfo.Bid());
   double fibPrice = 0;
   double tolerance = FibTolerancePoints * _Point;
   
   if(forBuy)
   {
      //--- For buy: retracement from swing low to swing high
      //--- Fib level: swing low + (swing high - swing low) * (1 - FibLevel)
      fibPrice = lastSwingLow + (lastSwingHigh - lastSwingLow) * (1.0 - FibLevel);
   }
   else
   {
      //--- For sell: retracement from swing high to swing low
      //--- Fib level: swing high - (swing high - swing low) * (1 - FibLevel)
      fibPrice = lastSwingHigh - (lastSwingHigh - lastSwingLow) * (1.0 - FibLevel);
   }
   
   //--- Check if current price is within tolerance
   bool nearFib = (MathAbs(currentPrice - fibPrice) <= tolerance);
   
   if(VerboseLogging && nearFib)
   {
      Print("📊 Price near ", DoubleToString(FibLevel, 3), " Fib level: ",
            "Current=", DoubleToString(currentPrice, _Digits),
            " | Fib=", DoubleToString(fibPrice, _Digits));
   }
   
   return nearFib;
}

//+------------------------------------------------------------------+
//| Get entry signal                                                  |
//+------------------------------------------------------------------+
int GetEntrySignal()
{
   //--- Get trend direction
   int trend = GetTrendDirection();
   
   if(trend == 0)
      return 0; // No clear trend
   
   //--- Check for buy signal
   if(trend == 1)
   {
      if(IsEngulfingCandle(true) && IsNearFibonacciLevel(true))
      {
         if(VerboseLogging)
            Print("🟢 BUY SIGNAL: Trend=Bullish | Engulfing=Yes | Fib=Yes");
         return 1;
      }
   }
   
   //--- Check for sell signal
   if(trend == -1)
   {
      if(IsEngulfingCandle(false) && IsNearFibonacciLevel(false))
      {
         if(VerboseLogging)
            Print("🔴 SELL SIGNAL: Trend=Bearish | Engulfing=Yes | Fib=Yes");
         return -1;
      }
   }
   
   return 0; // No signal
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips)
{
   //--- Get account balance
   double balance = account.Balance();
   
   //--- Calculate risk amount in account currency
   double riskAmount = balance * (RiskPerTrade / 100.0);
   
   //--- Get tick value and size
   double tickValue = symbolInfo.TickValue();
   double tickSize = symbolInfo.TickSize();
   double point = symbolInfo.Point();
   
   //--- Calculate stop loss in price units
   double stopLossPrice = stopLossPips * point;
   
   //--- Calculate lot size
   //--- LotSize = RiskAmount / (StopLoss in ticks * TickValue)
   double stopLossInTicks = stopLossPrice / tickSize;
   double lotSize = riskAmount / (stopLossInTicks * tickValue);
   
   //--- Normalize lot size
   double minLot = symbolInfo.LotsMin();
   double maxLot = symbolInfo.LotsMax();
   double lotStep = symbolInfo.LotsStep();
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   if(VerboseLogging)
   {
      Print("💰 Lot Calculation: Balance=$", DoubleToString(balance, 2),
            " | Risk=", DoubleToString(RiskPerTrade, 2), "%",
            " | SL=", DoubleToString(stopLossPips, 1), " pips",
            " | Lot=", DoubleToString(lotSize, 2));
   }
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate stop loss level                                         |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy)
{
   double sl = 0;
   double currentPrice = (isBuy ? symbolInfo.Ask() : symbolInfo.Bid());
   
   //--- Find recent swing point
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, EntryTimeframe, 0, 50, rates) < 50)
      return 0;
   
   double swingLevel = 0;
   
   if(isBuy)
   {
      //--- Find recent swing low
      swingLevel = rates[0].low;
      for(int i = 1; i < 20; i++)
      {
         if(rates[i].low < swingLevel)
            swingLevel = rates[i].low;
      }
      sl = swingLevel - 10 * _Point; // Small buffer
   }
   else
   {
      //--- Find recent swing high
      swingLevel = rates[0].high;
      for(int i = 1; i < 20; i++)
      {
         if(rates[i].high > swingLevel)
            swingLevel = rates[i].high;
      }
      sl = swingLevel + 10 * _Point; // Small buffer
   }
   
   //--- Apply minimum and maximum stop loss
   double minSL = currentPrice + (isBuy ? -1 : 1) * MinStopLossPips * _Point * 10;
   double maxSL = currentPrice + (isBuy ? -1 : 1) * MaxStopLossPips * _Point * 10;
   
   if(isBuy)
   {
      sl = MathMax(sl, minSL);
      sl = MathMin(sl, maxSL);
   }
   else
   {
      sl = MathMin(sl, minSL);
      sl = MathMax(sl, maxSL);
   }
   
   return NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| Execute buy order                                                 |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
   double ask = symbolInfo.Ask();
   double sl = CalculateStopLoss(true);
   
   if(sl == 0)
   {
      Print("❌ Failed to calculate stop loss for BUY");
      return;
   }
   
   double slPips = (ask - sl) / (_Point * 10);
   double lots = CalculateLotSize(slPips);
   
   if(lots < symbolInfo.LotsMin())
   {
      Print("❌ Calculated lot size too small: ", lots);
      return;
   }
   
   double tp = ask + (ask - sl) * RiskRewardRatio;
   tp = NormalizeDouble(tp, _Digits);
   
   //--- Execute trade
   string comment = CommentPrefix + "_BUY";
   bool result = trade.Buy(lots, _Symbol, ask, sl, tp, comment);
   
   if(result)
   {
      dailyTradeCount++;
      Print("✅ BUY ORDER OPENED: Lot=", DoubleToString(lots, 2),
            " | Entry=", DoubleToString(ask, _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits),
            " | R:R=1:", DoubleToString(RiskRewardRatio, 1));
   }
   else
   {
      Print("❌ BUY ORDER FAILED: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Execute sell order                                                |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
   double bid = symbolInfo.Bid();
   double sl = CalculateStopLoss(false);
   
   if(sl == 0)
   {
      Print("❌ Failed to calculate stop loss for SELL");
      return;
   }
   
   double slPips = (sl - bid) / (_Point * 10);
   double lots = CalculateLotSize(slPips);
   
   if(lots < symbolInfo.LotsMin())
   {
      Print("❌ Calculated lot size too small: ", lots);
      return;
   }
   
   double tp = bid - (sl - bid) * RiskRewardRatio;
   tp = NormalizeDouble(tp, _Digits);
   
   //--- Execute trade
   string comment = CommentPrefix + "_SELL";
   bool result = trade.Sell(lots, _Symbol, bid, sl, tp, comment);
   
   if(result)
   {
      dailyTradeCount++;
      Print("✅ SELL ORDER OPENED: Lot=", DoubleToString(lots, 2),
            " | Entry=", DoubleToString(bid, _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits),
            " | R:R=1:", DoubleToString(RiskRewardRatio, 1));
   }
   else
   {
      Print("❌ SELL ORDER FAILED: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                  |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Manage open positions (BE, Trailing, Partial TP)                 |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!position.SelectByIndex(i))
         continue;
      
      if(position.Symbol() != _Symbol || position.Magic() != MagicNumber)
         continue;
      
      ulong ticket = position.Ticket();
      double openPrice = position.PriceOpen();
      double currentSL = position.StopLoss();
      double currentTP = position.TakeProfit();
      double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? symbolInfo.Bid() : symbolInfo.Ask();
      
      //--- Calculate profit in R (Risk units)
      double risk = MathAbs(openPrice - currentSL);
      double profit = 0;
      
      if(position.PositionType() == POSITION_TYPE_BUY)
         profit = currentPrice - openPrice;
      else
         profit = openPrice - currentPrice;
      
      double rMultiple = (risk > 0) ? (profit / risk) : 0;
      
      //--- Move to break-even
      if(UseBreakEven && rMultiple >= BreakEvenRatio)
      {
         double newSL = openPrice + (position.PositionType() == POSITION_TYPE_BUY ? 1 : -1) * BreakEvenPlusPips * _Point * 10;
         newSL = NormalizeDouble(newSL, _Digits);
         
         bool needsUpdate = false;
         if(position.PositionType() == POSITION_TYPE_BUY && currentSL < newSL)
            needsUpdate = true;
         if(position.PositionType() == POSITION_TYPE_SELL && currentSL > newSL)
            needsUpdate = true;
         
         if(needsUpdate)
         {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
               Print("🔒 Break-Even activated for #", ticket, " | New SL=", DoubleToString(newSL, _Digits));
            }
         }
      }
      
      //--- Partial take profit
      if(UsePartialTP && rMultiple >= PartialTPRatio)
      {
         //--- Check if partial TP already taken (we can check comment or volume)
         double originalVolume = position.Volume();
         
         //--- Close partial position
         double closeVolume = NormalizeDouble(originalVolume * (PartialTPPercent / 100.0), 2);
         
         if(closeVolume >= symbolInfo.LotsMin())
         {
            if(trade.PositionClosePartial(ticket, closeVolume))
            {
               Print("💰 Partial TP executed for #", ticket,
                     " | Closed ", DoubleToString(PartialTPPercent, 0), "% at ",
                     DoubleToString(PartialTPRatio, 1), "R");
            }
         }
      }
      
      //--- Trailing stop
      if(UseTrailingStop && rMultiple >= TrailingStartRatio)
      {
         double trailDistance = TrailingStopPips * _Point * 10;
         double newSL = 0;
         
         if(position.PositionType() == POSITION_TYPE_BUY)
         {
            newSL = currentPrice - trailDistance;
            newSL = NormalizeDouble(newSL, _Digits);
            
            if(newSL > currentSL + TrailingStepPips * _Point * 10)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("📈 Trailing Stop updated for #", ticket, " | New SL=", DoubleToString(newSL, _Digits));
               }
            }
         }
         else // SELL
         {
            newSL = currentPrice + trailDistance;
            newSL = NormalizeDouble(newSL, _Digits);
            
            if(newSL < currentSL - TrailingStepPips * _Point * 10)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  Print("📉 Trailing Stop updated for #", ticket, " | New SL=", DoubleToString(newSL, _Digits));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check prop firm safety rules                                      |
//+------------------------------------------------------------------+
bool CheckPropFirmSafety()
{
   if(!tradingEnabled)
      return false;
   
   double currentBalance = account.Balance();
   double currentEquity = account.Equity();
   
   //--- Update peak balance
   if(currentBalance > peakBalance)
      peakBalance = currentBalance;
   
   //--- Calculate daily P/L
   dailyProfitLoss = currentBalance - dailyStartBalance;
   double dailyLossPercent = (dailyStartBalance > 0) ? (dailyProfitLoss / dailyStartBalance * 100.0) : 0;
   
   //--- Check daily loss limit
   if(dailyLossPercent <= -MaxDailyLossPercent)
   {
      Print("🚨 DAILY LOSS LIMIT REACHED: ", DoubleToString(dailyLossPercent, 2), "%");
      dailyLimitReached = true;
      CloseAllPositions("Daily loss limit");
      return false;
   }
   
   //--- Calculate weekly P/L
   weeklyProfitLoss = currentBalance - weeklyStartBalance;
   double weeklyLossPercent = (weeklyStartBalance > 0) ? (weeklyProfitLoss / weeklyStartBalance * 100.0) : 0;
   
   //--- Check weekly loss limit
   if(weeklyLossPercent <= -MaxWeeklyLossPercent)
   {
      Print("🚨 WEEKLY LOSS LIMIT REACHED: ", DoubleToString(weeklyLossPercent, 2), "%");
      tradingEnabled = false;
      CloseAllPositions("Weekly loss limit");
      return false;
   }
   
   //--- Calculate total drawdown from peak
   double drawdownPercent = ((peakBalance - currentEquity) / peakBalance) * 100.0;
   
   //--- Check max drawdown limit
   if(drawdownPercent >= MaxTotalDrawdownPercent)
   {
      Print("🚨 MAX DRAWDOWN REACHED: ", DoubleToString(drawdownPercent, 2), "%");
      tradingEnabled = false;
      CloseAllPositions("Max drawdown");
      return false;
   }
   
   //--- Check consecutive losses
   if(consecutiveLosses >= MaxConsecutiveLosses)
   {
      Print("🚨 MAX CONSECUTIVE LOSSES REACHED: ", consecutiveLosses);
      dailyLimitReached = true;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   Print("🛑 Closing all positions: ", reason);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
         {
            trade.PositionClose(position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check daily reset                                                 |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   if(!EnableDailyReset)
      return;
   
   datetime currentTime = TimeCurrent();
   MqlDateTime dtStruct;
   TimeToStruct(currentTime, dtStruct);
   
   //--- Calculate today's midnight
   dtStruct.hour = 0;
   dtStruct.min = 0;
   dtStruct.sec = 0;
   datetime todayMidnight = StructToTime(dtStruct);
   
   //--- Check if we've crossed into a new day
   if(todayMidnight > dailyResetTime)
   {
      Print("═══════════════════════════════════════════════════════════");
      Print("🔄 DAILY RESET");
      Print("═══════════════════════════════════════════════════════════");
      Print("📊 Previous Day Summary:");
      Print("   - Trades: ", dailyTradeCount);
      Print("   - Wins: ", dailyWins);
      Print("   - Losses: ", dailyLosses);
      Print("   - P/L: $", DoubleToString(dailyProfitLoss, 2),
            " (", DoubleToString((dailyProfitLoss/dailyStartBalance*100), 2), "%)");
      Print("═══════════════════════════════════════════════════════════");
      
      //--- Reset daily counters
      dailyResetTime = todayMidnight;
      dailyStartBalance = account.Balance();
      dailyTradeCount = 0;
      dailyWins = 0;
      dailyLosses = 0;
      dailyProfitLoss = 0;
      dailyLimitReached = false;
      
      //--- Check if new week
      if(dtStruct.day_of_week == 1) // Monday
      {
         Print("🔄 WEEKLY RESET");
         weeklyResetTime = todayMidnight;
         weeklyStartBalance = account.Balance();
         weeklyProfitLoss = 0;
         tradingEnabled = true; // Re-enable trading for new week
         consecutiveLosses = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if within trading session                                   |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
{
   MqlDateTime dtStruct;
   TimeToStruct(TimeCurrent(), dtStruct);
   
   int currentHour = dtStruct.hour;
   
   //--- Check if within session hours
   if(currentHour >= SessionStartHour && currentHour < SessionEndHour)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Create dashboard                                                  |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   //--- Create background rectangle
   string bgName = dashboardName + "_BG";
   
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 280);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 300);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Update dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   //--- Calculate current stats
   double currentBalance = account.Balance();
   double currentEquity = account.Equity();
   double dailyPL = currentBalance - dailyStartBalance;
   double dailyPLPercent = (dailyStartBalance > 0) ? (dailyPL / dailyStartBalance * 100.0) : 0;
   double drawdown = ((peakBalance - currentEquity) / peakBalance) * 100.0;
   int openTrades = CountOpenPositions();
   int trend = GetTrendDirection();
   string trendText = (trend == 1) ? "BULLISH" : (trend == -1) ? "BEARISH" : "NEUTRAL";
   color trendColor = (trend == 1) ? clrLime : (trend == -1) ? clrRed : clrGray;
   
   //--- Build dashboard text
   string dashText = "";
   dashText += "═══ GOLD PROP EA ═══\n";
   dashText += "Balance: $" + DoubleToString(currentBalance, 2) + "\n";
   dashText += "Equity: $" + DoubleToString(currentEquity, 2) + "\n";
   dashText += "Drawdown: " + DoubleToString(drawdown, 2) + "%\n";
   dashText += "─────────────────────\n";
   dashText += "Daily P/L: $" + DoubleToString(dailyPL, 2) + "\n";
   dashText += "Daily %: " + DoubleToString(dailyPLPercent, 2) + "%\n";
   dashText += "Trades Today: " + IntegerToString(dailyTradeCount) + "/" + IntegerToString(MaxTradesPerDay) + "\n";
   dashText += "─────────────────────\n";
   dashText += "Open Positions: " + IntegerToString(openTrades) + "\n";
   dashText += "Risk/Trade: " + DoubleToString(RiskPerTrade, 2) + "%\n";
   dashText += "Trend: " + trendText + "\n";
   dashText += "─────────────────────\n";
   dashText += "Wins: " + IntegerToString(dailyWins) + " | Losses: " + IntegerToString(dailyLosses) + "\n";
   dashText += "Status: " + (tradingEnabled ? "ACTIVE" : "DISABLED");
   
   //--- Create or update label
   string labelName = dashboardName + "_Text";
   
   if(ObjectFind(0, labelName) < 0)
   {
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Courier New");
   }
   
   ObjectSetString(0, labelName, OBJPROP_TEXT, dashText);
}

//+------------------------------------------------------------------+
//| OnTrade event handler                                             |
//+------------------------------------------------------------------+
void OnTrade()
{
   //--- Check if it's our position
   HistorySelect(TimeCurrent() - 86400, TimeCurrent()); // Last 24 hours
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      if(dealTicket > 0)
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         
         if(dealMagic == MagicNumber)
         {
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            
            //--- Only count closing deals
            if(dealEntry == DEAL_ENTRY_OUT)
            {
               if(dealProfit > 0)
               {
                  dailyWins++;
                  consecutiveLosses = 0;
                  Print("✅ Trade closed with PROFIT: $", DoubleToString(dealProfit, 2));
               }
               else if(dealProfit < 0)
               {
                  dailyLosses++;
                  consecutiveLosses++;
                  Print("❌ Trade closed with LOSS: $", DoubleToString(dealProfit, 2),
                        " | Consecutive losses: ", consecutiveLosses);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                         END OF EA                                 |
//+------------------------------------------------------------------+
