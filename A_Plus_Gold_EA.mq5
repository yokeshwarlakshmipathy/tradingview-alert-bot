//+------------------------------------------------------------------+
//|                                             A_Plus_Gold_EA.mq5  |
//|                        Expert Advisor for XAUUSD Prop Firm EA   |
//|                        A+ Setup Only - High Confluence Trading   |
//+------------------------------------------------------------------+
#property copyright "Prop Firm Strategy EA"
#property link      ""
#property version   "1.00"
#property strict
#property description "A+ Gold Trading Strategy - Optimized for Prop Firm Challenges"
#property description "M15 entries with H1 trend filter, engulfing + Fib confluence"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
//--- Trading Parameters
input group "=== Trading Settings ==="
input double   RiskPerTrade = 1.0;              // Risk per trade (% of balance)
input double   RiskRewardRatio = 3.0;           // Risk:Reward ratio (default 1:3)
input int      PartialTPPercent = 50;           // Partial TP % at 1:2R
input int      MagicNumber = 123456;            // Magic number for trades
input string   TradeSymbol = "XAUUSD";          // Trading symbol

//--- Trend Filter Parameters
input group "=== Trend Filter Settings ==="
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H1;  // Trend timeframe (H1/H4)
input int      EMA_Fast = 20;                   // Fast EMA period
input int      EMA_Slow = 50;                   // Slow EMA period

//--- Entry Signal Parameters
input group "=== Entry Signal Settings ==="
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_M15;  // Entry timeframe
input double   FibRetracement = 0.618;          // Fibonacci retracement level
input int      FibTolerancePips = 30;           // Fib tolerance in points
input bool     RequireEngulfing = true;         // Require engulfing candle

//--- Risk Management
input group "=== Risk Management ==="
input int      MinStopLossPips = 50;            // Minimum stop loss (points)
input bool     UseBreakEven = true;             // Enable break-even move
input double   BreakEvenTrigger = 1.0;          // Break-even trigger (in R)
input bool     UseTrailingStop = true;          // Enable trailing stop
input double   TrailingStart = 1.5;             // Trailing start (in R)
input double   TrailingStep = 0.3;             // Trailing step (in R)

//--- Prop Firm Safety Rules
input group "=== Prop Firm Safety Rules ==="
input double   MaxDailyLossPercent = 5.0;       // Max daily loss (%)
input double   MaxWeeklyLossPercent = 10.0;     // Max weekly loss (%)
input double   MaxDrawdownPercent = 12.0;       // Max total drawdown (%)
input int      MaxConsecutiveLosses = 3;        // Max consecutive losses
input int      MaxTradesPerDay = 5;             // Max trades per day
input bool     EnableSessionFilter = true;      // Enable session filter
input int      SessionStartHour = 7;            // Session start (UTC hour)
input int      SessionEndHour = 20;             // Session end (UTC hour)
input bool     EnableEquityProtection = true;   // Enable equity protection

//--- Display Settings
input group "=== Display Settings ==="
input bool     ShowInfoPanel = true;            // Show on-chart info panel
input int      PanelX = 20;                     // Panel X position
input int      PanelY = 30;                    // Panel Y position

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;

// EMA Handles
int            ema_fast_handle;
int            ema_slow_handle;
int            ema_fast_entry_handle;
int            ema_slow_entry_handle;

// Daily/Weekly Tracking
datetime       lastBarTime = 0;
datetime       dailyResetTime = 0;
datetime       weekStartTime = 0;
double         dailyStartBalance = 0;
double         weeklyStartBalance = 0;
double         dailyProfit = 0;
double         weeklyProfit = 0;
int            tradesToday = 0;
int            consecutiveLosses = 0;
int            totalWins = 0;
int            totalLosses = 0;

// Trade Management
string         lastTradeDirection = "";
double         lastTradeLots = 0;
ulong          partialTPTicket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   //--- Initialize EMA handles for trend timeframe
   ema_fast_handle = iMA(_Symbol, TrendTimeframe, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   ema_slow_handle = iMA(_Symbol, TrendTimeframe, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema_fast_handle == INVALID_HANDLE || ema_slow_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create EMA indicators");
      return(INIT_FAILED);
   }
   
   //--- Initialize EMA handles for entry timeframe
   ema_fast_entry_handle = iMA(_Symbol, EntryTimeframe, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   ema_slow_entry_handle = iMA(_Symbol, EntryTimeframe, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema_fast_entry_handle == INVALID_HANDLE || ema_slow_entry_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create entry timeframe EMA indicators");
      return(INIT_FAILED);
   }
   
   //--- Initialize daily/weekly tracking
   ResetDailyStats();
   ResetWeeklyStats();
   
   //--- Validate symbol
   if(_Symbol != TradeSymbol)
   {
      Print("WARNING: EA is configured for ", TradeSymbol, " but chart is ", _Symbol);
   }
   
   //--- Create info panel
   if(ShowInfoPanel)
   {
      CreateInfoPanel();
   }
   
   Print("A+ Gold EA initialized successfully");
   Print("Symbol: ", _Symbol, " | Risk: ", RiskPerTrade, "% | R:R: 1:", RiskRewardRatio);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
   if(ema_fast_entry_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_entry_handle);
   if(ema_slow_entry_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_entry_handle);
   
   //--- Remove info panel
   if(ShowInfoPanel)
   {
      RemoveInfoPanel();
   }
   
   Print("A+ Gold EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   datetime currentBarTime = iTime(_Symbol, EntryTimeframe, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
      CheckDailyReset();
      CheckWeeklyReset();
   }
   
   //--- Update tracking
   UpdateDailyStats();
   UpdateWeeklyStats();
   
   //--- Safety checks
   if(!CheckSafetyRules())
   {
      if(isNewBar) Print("Trading disabled due to safety rule breach");
      ManageOpenPositions();
      if(ShowInfoPanel) UpdateInfoPanel();
      return;
   }
   
   //--- Session filter
   if(EnableSessionFilter && !IsWithinSession())
   {
      ManageOpenPositions();
      if(ShowInfoPanel) UpdateInfoPanel();
      return;
   }
   
   //--- Manage existing positions
   ManageOpenPositions();
   
   //--- Check for new entry signals (only on new bar)
   if(isNewBar && CountOpenPositions() == 0)
   {
      CheckEntrySignals();
   }
   
   //--- Update info panel
   if(ShowInfoPanel) UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   //--- Check trend direction on HTF
   int trendDirection = GetTrendDirection();
   if(trendDirection == 0) return; // No clear trend
   
   //--- Check for engulfing pattern
   if(RequireEngulfing && !IsEngulfingCandle(trendDirection))
   {
      return;
   }
   
   //--- Check Fibonacci retracement
   if(!IsNearFibLevel(trendDirection))
   {
      return;
   }
   
   //--- All conditions met - execute trade
   if(trendDirection == 1) // Bullish
   {
      ExecuteBuy();
   }
   else if(trendDirection == -1) // Bearish
   {
      ExecuteSell();
   }
}

//+------------------------------------------------------------------+
//| Get trend direction from HTF EMAs                                |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
   double ema_fast[], ema_slow[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   
   if(CopyBuffer(ema_fast_handle, 0, 0, 2, ema_fast) <= 0 ||
      CopyBuffer(ema_slow_handle, 0, 0, 2, ema_slow) <= 0)
   {
      return 0;
   }
   
   if(ema_fast[0] > ema_slow[0] && ema_fast[1] > ema_slow[1])
      return 1; // Bullish trend
   else if(ema_fast[0] < ema_slow[0] && ema_fast[1] < ema_slow[1])
      return -1; // Bearish trend
   
   return 0; // No clear trend
}

//+------------------------------------------------------------------+
//| Check for engulfing candle pattern                               |
//+------------------------------------------------------------------+
bool IsEngulfingCandle(int direction)
{
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyOpen(_Symbol, EntryTimeframe, 0, 2, open) <= 0 ||
      CopyClose(_Symbol, EntryTimeframe, 0, 2, close) <= 0 ||
      CopyHigh(_Symbol, EntryTimeframe, 0, 2, high) <= 0 ||
      CopyLow(_Symbol, EntryTimeframe, 0, 2, low) <= 0)
   {
      return false;
   }
   
   // Bullish engulfing: previous candle bearish, current candle bullish and engulfs previous
   if(direction == 1)
   {
      bool prevBearish = close[1] < open[1];
      bool currBullish = close[0] > open[0];
      bool engulfs = open[0] < close[1] && close[0] > open[1];
      return (prevBearish && currBullish && engulfs);
   }
   // Bearish engulfing: previous candle bullish, current candle bearish and engulfs previous
   else if(direction == -1)
   {
      bool prevBullish = close[1] > open[1];
      bool currBearish = close[0] < open[0];
      bool engulfs = open[0] > close[1] && close[0] < open[1];
      return (prevBullish && currBearish && engulfs);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is near Fibonacci retracement level              |
//+------------------------------------------------------------------+
bool IsNearFibLevel(int direction)
{
   // Find recent swing high and low
   double swingHigh = FindSwingHigh(EntryTimeframe, 20);
   double swingLow = FindSwingLow(EntryTimeframe, 20);
   
   if(swingHigh == 0 || swingLow == 0) return false;
   
   double range = swingHigh - swingLow;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate Fib level
   double fibLevel;
   if(direction == 1) // Bullish - looking for retracement from high
   {
      fibLevel = swingHigh - (range * FibRetracement);
      double tolerance = FibTolerancePips * GetPointValue();
      return (currentPrice >= fibLevel - tolerance && currentPrice <= fibLevel + tolerance);
   }
   else if(direction == -1) // Bearish - looking for retracement from low
   {
      fibLevel = swingLow + (range * FibRetracement);
      double tolerance = FibTolerancePips * GetPointValue();
      return (currentPrice >= fibLevel - tolerance && currentPrice <= fibLevel + tolerance);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Find swing high                                                  |
//+------------------------------------------------------------------+
double FindSwingHigh(ENUM_TIMEFRAMES tf, int lookback)
{
   double high[];
   ArraySetAsSeries(high, true);
   
   if(CopyHigh(_Symbol, tf, 0, lookback, high) <= 0)
      return 0;
   
   int highestBar = ArrayMaximum(high, 1, lookback - 1);
   return high[highestBar];
}

//+------------------------------------------------------------------+
//| Find swing low                                                   |
//+------------------------------------------------------------------+
double FindSwingLow(ENUM_TIMEFRAMES tf, int lookback)
{
   double low[];
   ArraySetAsSeries(low, true);
   
   if(CopyLow(_Symbol, tf, 0, lookback, low) <= 0)
      return 0;
   
   int lowestBar = ArrayMinimum(low, 1, lookback - 1);
   return low[lowestBar];
}

//+------------------------------------------------------------------+
//| Execute buy order                                                |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   if(tradesToday >= MaxTradesPerDay)
   {
      Print("Max trades per day reached");
      return;
   }
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = CalculateStopLoss(ORDER_TYPE_BUY);
   double takeProfit = CalculateTakeProfit(ORDER_TYPE_BUY, stopLoss, price);
   double lotSize = CalculateLotSize(price, stopLoss);
   
   if(lotSize <= 0)
   {
      Print("ERROR: Invalid lot size calculated");
      return;
   }
   
   // Normalize prices
   price = NormalizeDouble(price, _Digits);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   if(trade.Buy(lotSize, _Symbol, price, stopLoss, takeProfit, "A+ Gold Buy"))
   {
      Print("BUY order executed: Lots=", lotSize, " SL=", stopLoss, " TP=", takeProfit);
      lastTradeDirection = "BUY";
      lastTradeLots = lotSize;
      tradesToday++;
      partialTPTicket = 0;
   }
   else
   {
      Print("ERROR: Buy order failed. Code: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Execute sell order                                               |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   if(tradesToday >= MaxTradesPerDay)
   {
      Print("Max trades per day reached");
      return;
   }
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = CalculateStopLoss(ORDER_TYPE_SELL);
   double takeProfit = CalculateTakeProfit(ORDER_TYPE_SELL, stopLoss, price);
   double lotSize = CalculateLotSize(price, stopLoss);
   
   if(lotSize <= 0)
   {
      Print("ERROR: Invalid lot size calculated");
      return;
   }
   
   // Normalize prices
   price = NormalizeDouble(price, _Digits);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   if(trade.Sell(lotSize, _Symbol, price, stopLoss, takeProfit, "A+ Gold Sell"))
   {
      Print("SELL order executed: Lots=", lotSize, " SL=", stopLoss, " TP=", takeProfit);
      lastTradeDirection = "SELL";
      lastTradeLots = lotSize;
      tradesToday++;
      partialTPTicket = 0;
   }
   else
   {
      Print("ERROR: Sell order failed. Code: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType)
{
   double swingLevel;
   double minStopLoss = MinStopLossPips * GetPointValue();
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      swingLevel = FindSwingLow(EntryTimeframe, 20);
      if(swingLevel == 0 || swingLevel > currentPrice)
         swingLevel = currentPrice - minStopLoss;
      else
         swingLevel = MathMin(swingLevel, currentPrice - minStopLoss);
   }
   else // SELL
   {
      swingLevel = FindSwingHigh(EntryTimeframe, 20);
      if(swingLevel == 0 || swingLevel < currentPrice)
         swingLevel = currentPrice + minStopLoss;
      else
         swingLevel = MathMax(swingLevel, currentPrice + minStopLoss);
   }
   
   return NormalizeDouble(swingLevel, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double stopLoss, double entryPrice)
{
   double risk = MathAbs(entryPrice - stopLoss);
   double reward = risk * RiskRewardRatio;
   
   double takeProfit;
   if(orderType == ORDER_TYPE_BUY)
      takeProfit = entryPrice + reward;
   else
      takeProfit = entryPrice - reward;
   
   return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss)
{
   double riskAmount = account.Balance() * (RiskPerTrade / 100.0);
   double riskInPoints = MathAbs(entryPrice - stopLoss);
   
   if(riskInPoints <= 0) return 0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = (tickValue / tickSize) * _Point;
   
   double lotSize = riskAmount / (riskInPoints * pointValue);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Get point value for current symbol                               |
//+------------------------------------------------------------------+
double GetPointValue()
{
   return _Point;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         
         // Manage partial TP
         ManagePartialTP(ticket);
         
         // Manage break-even
         if(UseBreakEven) ManageBreakEven(ticket);
         
         // Manage trailing stop
         if(UseTrailingStop) ManageTrailingStop(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage partial take profit                                       |
//+------------------------------------------------------------------+
void ManagePartialTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = PositionGetDouble(POSITION_SL);
   double lots = PositionGetDouble(POSITION_VOLUME);
   
   if(lots <= 0 || stopLoss == 0) return;
   
   double risk = MathAbs(openPrice - stopLoss);
   double profit = MathAbs(currentPrice - openPrice);
   double profitInR = profit / risk;
   
   // Check if we've reached 1:2R and haven't taken partial yet
   if(profitInR >= 2.0 && partialTPTicket != ticket)
   {
      double partialLots = NormalizeDouble(lots * (PartialTPPercent / 100.0), 2);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      
      if(partialLots >= minLot && (lots - partialLots) >= minLot)
      {
         if(trade.PositionClosePartial(ticket, partialLots))
         {
            Print("Partial TP executed: ", PartialTPPercent, "% at 1:2R");
            partialTPTicket = ticket;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage break-even                                                |
//+------------------------------------------------------------------+
void ManageBreakEven(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = PositionGetDouble(POSITION_SL);
   double lots = PositionGetDouble(POSITION_VOLUME);
   
   if(lots <= 0 || stopLoss == 0) return;
   
   double risk = MathAbs(openPrice - stopLoss);
   double profit = MathAbs(currentPrice - openPrice);
   double profitInR = profit / risk;
   
   // Move SL to break-even when profit reaches trigger level
   if(profitInR >= BreakEvenTrigger)
   {
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double newSL = openPrice;
      double currentSL = stopLoss;
      
      // Only move if not already at break-even or better
      if((posType == POSITION_TYPE_BUY && currentSL < newSL) ||
         (posType == POSITION_TYPE_SELL && currentSL > newSL))
      {
         double tp = PositionGetDouble(POSITION_TP);
         if(trade.PositionModify(ticket, newSL, tp))
         {
            Print("Break-even moved to entry price");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = PositionGetDouble(POSITION_SL);
   double lots = PositionGetDouble(POSITION_VOLUME);
   
   if(lots <= 0 || stopLoss == 0) return;
   
   double risk = MathAbs(openPrice - stopLoss);
   if(risk <= 0) return;
   
   double profit = MathAbs(currentPrice - openPrice);
   double profitInR = profit / risk;
   
   // Start trailing after trigger level
   if(profitInR >= TrailingStart)
   {
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double trailingDistance = risk * TrailingStep;
      double newSL;
      
      if(posType == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - trailingDistance;
         if(newSL > stopLoss && newSL < currentPrice)
         {
            double tp = PositionGetDouble(POSITION_TP);
            if(trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp))
            {
               Print("Trailing stop updated to: ", newSL);
            }
         }
      }
      else // SELL
      {
         newSL = currentPrice + trailingDistance;
         if(newSL < stopLoss && newSL > currentPrice)
         {
            double tp = PositionGetDouble(POSITION_TP);
            if(trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp))
            {
               Print("Trailing stop updated to: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check safety rules                                               |
//+------------------------------------------------------------------+
bool CheckSafetyRules()
{
   // Check daily loss
   double dailyLossPercent = ((dailyStartBalance - account.Balance()) / dailyStartBalance) * 100.0;
   if(dailyLossPercent >= MaxDailyLossPercent)
   {
      Print("Daily loss limit breached: ", DoubleToString(dailyLossPercent, 2), "%");
      return false;
   }
   
   // Check weekly loss
   double weeklyLossPercent = ((weeklyStartBalance - account.Balance()) / weeklyStartBalance) * 100.0;
   if(weeklyLossPercent >= MaxWeeklyLossPercent)
   {
      Print("Weekly loss limit breached: ", DoubleToString(weeklyLossPercent, 2), "%");
      return false;
   }
   
   // Check total drawdown
   double currentDrawdown = GetCurrentDrawdown();
   if(currentDrawdown >= MaxDrawdownPercent)
   {
      Print("Total drawdown limit breached: ", DoubleToString(currentDrawdown, 2), "%");
      if(EnableEquityProtection)
      {
         CloseAllPositions();
      }
      return false;
   }
   
   // Check consecutive losses
   if(consecutiveLosses >= MaxConsecutiveLosses)
   {
      Print("Max consecutive losses reached: ", consecutiveLosses);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get current drawdown percentage                                  |
//+------------------------------------------------------------------+
double GetCurrentDrawdown()
{
   double equity = account.Equity();
   double balance = account.Balance();
   if(balance <= 0) return 0;
   
   double drawdown = ((balance - equity) / balance) * 100.0;
   return drawdown;
}

//+------------------------------------------------------------------+
//| Check if within trading session                                  |
//+------------------------------------------------------------------+
bool IsWithinSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int currentHour = dt.hour;
   
   if(SessionStartHour <= SessionEndHour)
   {
      return (currentHour >= SessionStartHour && currentHour < SessionEndHour);
   }
   else // Session spans midnight
   {
      return (currentHour >= SessionStartHour || currentHour < SessionEndHour);
   }
}

//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Reset daily statistics                                           |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   dailyResetTime = StructToTime(dt);
   
   dailyStartBalance = account.Balance();
   dailyProfit = 0;
   tradesToday = 0;
}

//+------------------------------------------------------------------+
//| Reset weekly statistics                                          |
//+------------------------------------------------------------------+
void ResetWeeklyStats()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int dayOfWeek = dt.day_of_week;
   int daysToMonday = (dayOfWeek == 0) ? 6 : (dayOfWeek - 1);
   
   dt.day -= daysToMonday;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   weekStartTime = StructToTime(dt);
   
   weeklyStartBalance = account.Balance();
   weeklyProfit = 0;
}

//+------------------------------------------------------------------+
//| Check daily reset                                                |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   datetime currentTime = TimeCurrent();
   if(currentTime >= dailyResetTime + 86400) // New day
   {
      ResetDailyStats();
      Print("Daily stats reset at ", TimeToString(currentTime));
   }
}

//+------------------------------------------------------------------+
//| Check weekly reset                                               |
//+------------------------------------------------------------------+
void CheckWeeklyReset()
{
   datetime currentTime = TimeCurrent();
   if(currentTime >= weekStartTime + 604800) // New week
   {
      ResetWeeklyStats();
      Print("Weekly stats reset at ", TimeToString(currentTime));
   }
}

//+------------------------------------------------------------------+
//| Update daily statistics                                          |
//+------------------------------------------------------------------+
void UpdateDailyStats()
{
   dailyProfit = account.Balance() - dailyStartBalance;
}

//+------------------------------------------------------------------+
//| Update weekly statistics                                         |
//+------------------------------------------------------------------+
void UpdateWeeklyStats()
{
   weeklyProfit = account.Balance() - weeklyStartBalance;
}

//+------------------------------------------------------------------+
//| Track trade results                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Track wins/losses when position closes
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit > 0)
            {
               totalWins++;
               consecutiveLosses = 0;
            }
            else if(profit < 0)
            {
               totalLosses++;
               consecutiveLosses++;
            }
            break; // Only process latest closed trade
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create info panel                                                |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   // Panel will be created using ObjectCreate
   // This will be drawn in UpdateInfoPanel
}

//+------------------------------------------------------------------+
//| Update info panel                                                |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   string panelName = "A_Plus_Gold_Panel";
   
   // Remove existing panel
   ObjectDelete(0, panelName);
   
   // Create background
   int panelWidth = 300;
   int panelHeight = 250;
   ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, PanelY);
   ObjectSetInteger(0, panelName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   
   // Create text labels
   int yOffset = PanelY + 10;
   int lineHeight = 20;
   
   // Title
   CreateLabel("PanelTitle", PanelX + 10, yOffset, "A+ Gold EA Status", clrWhite, 10, true);
   yOffset += lineHeight + 5;
   
   // Balance & Equity
   double balance = account.Balance();
   double equity = account.Equity();
   CreateLabel("BalanceLabel", PanelX + 10, yOffset, "Balance: $" + DoubleToString(balance, 2), clrWhite, 9);
   yOffset += lineHeight;
   CreateLabel("EquityLabel", PanelX + 10, yOffset, "Equity: $" + DoubleToString(equity, 2), clrWhite, 9);
   yOffset += lineHeight;
   
   // Drawdown
   double drawdown = GetCurrentDrawdown();
   color ddColor = (drawdown > MaxDrawdownPercent * 0.8) ? clrRed : clrYellow;
   CreateLabel("DrawdownLabel", PanelX + 10, yOffset, "Drawdown: " + DoubleToString(drawdown, 2) + "%", ddColor, 9);
   yOffset += lineHeight;
   
   // Daily P/L
   double dailyPLPercent = (dailyStartBalance > 0) ? (dailyProfit / dailyStartBalance) * 100.0 : 0;
   color plColor = (dailyProfit >= 0) ? clrLime : clrRed;
   CreateLabel("DailyPLLabel", PanelX + 10, yOffset, "Daily P/L: " + DoubleToString(dailyPLPercent, 2) + "%", plColor, 9);
   yOffset += lineHeight;
   
   // Open Trades
   int openTrades = CountOpenPositions();
   CreateLabel("TradesLabel", PanelX + 10, yOffset, "Open Trades: " + IntegerToString(openTrades), clrWhite, 9);
   yOffset += lineHeight;
   
   // Risk per Trade
   CreateLabel("RiskLabel", PanelX + 10, yOffset, "Risk/Trade: " + DoubleToString(RiskPerTrade, 2) + "%", clrWhite, 9);
   yOffset += lineHeight;
   
   // Trend Direction
   int trend = GetTrendDirection();
   string trendText = (trend == 1) ? "BULLISH" : (trend == -1) ? "BEARISH" : "NEUTRAL";
   color trendColor = (trend == 1) ? clrLime : (trend == -1) ? clrRed : clrGray;
   CreateLabel("TrendLabel", PanelX + 10, yOffset, "Trend: " + trendText, trendColor, 9);
   yOffset += lineHeight;
   
   // Win Rate
   int totalTrades = totalWins + totalLosses;
   double winRate = (totalTrades > 0) ? (totalWins / (double)totalTrades) * 100.0 : 0;
   CreateLabel("WinRateLabel", PanelX + 10, yOffset, "Win Rate: " + DoubleToString(winRate, 1) + "% (" + 
               IntegerToString(totalWins) + "/" + IntegerToString(totalTrades) + ")", clrWhite, 9);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create text label                                                |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold = false)
{
   string fullName = "A_Plus_Gold_" + name;
   ObjectDelete(0, fullName);
   ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, fullName, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, fullName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Remove info panel                                                |
//+------------------------------------------------------------------+
void RemoveInfoPanel()
{
   ObjectsDeleteAll(0, "A_Plus_Gold_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
