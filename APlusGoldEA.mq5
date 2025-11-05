#property strict
#property copyright ""
#property link      ""
#property version   "1.00"
#property description "A+ Gold Prop-Firm Strategy EA"

#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

enum TrendBias
{
   TREND_NONE = 0,
   TREND_BULL = 1,
   TREND_BEAR = -1
};

class CPositionState : public CObject
{
public:
   ulong  ticket;
   bool   partial_done;
   bool   breakeven_done;
   double last_trail_price;

   CPositionState(): ticket(0), partial_done(false), breakeven_done(false), last_trail_price(0.0) {}
};

//--- inputs
input string           InpAllowedSymbols       = "XAUUSD";      // Allowed symbols (comma separated)
input ENUM_TIMEFRAMES  InpTrendTimeframe       = PERIOD_H1;      // Trend timeframe
input ENUM_TIMEFRAMES  InpEntryTimeframe       = PERIOD_M15;     // Entry timeframe
input int              InpFastEMAPeriod        = 20;             // Fast EMA period (trend)
input int              InpSlowEMAPeriod        = 50;             // Slow EMA period (trend)
input double           InpRiskPerTrade         = 1.0;            // Risk per trade (% of balance)
input double           InpMinimumStopPoints    = 300.0;          // Minimum stop distance (points)
input double           InpFibTolerancePoints   = 150.0;          // Fibonacci tolerance (points)
input double           InpRewardRiskMain       = 3.0;            // Take Profit R multiple
input double           InpPartialCloseRR       = 2.0;            // Partial close R multiple
input double           InpPartialClosePercent  = 50.0;           // Partial close percent
input bool             InpEnableBreakEven      = true;           // Enable break-even lock
input double           InpBreakEvenRR          = 1.0;            // Break-even trigger RR
input bool             InpEnableTrailing       = true;           // Enable trailing stop
input double           InpTrailingStartRR      = 1.5;            // Trailing start RR
input double           InpTrailingStepPoints   = 150.0;          // Trailing step (points)
input int              InpMaxSlippagePoints    = 100;            // Max deviation (points)
input double           InpMaxDailyLossPercent  = 4.0;            // Max daily loss %
input double           InpMaxWeeklyLossPercent = 8.0;            // Max weekly loss %
input double           InpHardDrawdownPercent  = 10.0;           // Hard overall drawdown %
input int              InpMaxConsecutiveLosses = 3;              // Max consecutive losses
input int              InpMaxTradesPerDay      = 3;              // Max trades per day
input bool             InpEnableSessionFilter  = true;           // Enable session filter
input int              InpSessionStartHourUTC  = 7;              // Session start hour UTC
input int              InpSessionEndHourUTC    = 20;             // Session end hour UTC
input bool             InpEnableNewsFilter     = false;          // Placeholder news filter
input bool             InpEnableDXYFilter      = false;          // Placeholder DXY filter
input bool             InpCloseOnHardDrawdown  = true;           // Close all trades on hard DD
input ulong            InpMagicNumber          = 56005500;       // Magic number
input string           InpTradeComment         = "APlusGoldEA"; // Trade comment
input string           InpPanelFont            = "Arial";       // Panel font
input int              InpPanelFontSize        = 10;             // Panel font size

//--- globals
CTrade           g_trade;
CArrayObj        g_position_states;

int      g_handle_fast = INVALID_HANDLE;
int      g_handle_slow = INVALID_HANDLE;

datetime g_daily_reset_gmt = 0;
datetime g_weekly_reset_gmt = 0;
double   g_daily_start_equity = 0.0;
double   g_weekly_start_equity = 0.0;
double   g_peak_equity = 0.0;
bool     g_daily_disabled = false;
bool     g_weekly_disabled = false;
bool     g_hard_dd_triggered = false;
int      g_consecutive_losses = 0;
int      g_trades_today = 0;

string   g_panel_name = "APlusGoldPanel";

//--- forward declarations
void ResetDailyStats();
void ResetWeeklyStats();
void UpdateEquityStats();
void CheckRiskLimits();
bool IsWithinSession();
bool IsAllowedSymbol(const string symbol);
bool NewsFilterAllows();
bool DXYFilterAllows();
int  PositionsTotalByMagic();
TrendBias GetTrendBias();
bool GetEntrySignal(TrendBias trend, double &entry_price, double &stop_loss, double &take_profit, double &partial_tp, double &risk_points);
bool DetectEngulfing(TrendBias trend);
bool FindSwingLevels(bool bullish, double &swing_high, double &swing_low);
double CalculateVolume(double stop_points);
void ManageOpenPositions();
void HandlePositionState(ulong ticket);
CPositionState* GetPositionState(const ulong ticket, const bool create_if_missing);
void RemovePositionState(const ulong ticket);
void RefreshPanel();
void CloseAllPositions();
double GetDailyPLPercent();
double GetWeeklyPLPercent();
double GetDrawdownPercent();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!IsAllowedSymbol(_Symbol))
   {
      PrintFormat("[Init] Symbol %s not allowed by EA.", _Symbol);
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(InpRewardRiskMain <= 0.0)
   {
      Print("[Init] Reward to risk multiple must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(InpEnableBreakEven && InpBreakEvenRR < 0.0)
   {
      Print("[Init] Break-even RR cannot be negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(InpPartialClosePercent > 0.0 && InpPartialCloseRR <= 0.0)
   {
      Print("[Init] Partial close RR must be positive when partial close is enabled.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);

   g_handle_fast = iMA(_Symbol, InpTrendTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_handle_slow = iMA(_Symbol, InpTrendTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_handle_fast == INVALID_HANDLE || g_handle_slow == INVALID_HANDLE)
   {
      Print("[Init] Failed to create EMA handles.");
      return(INIT_FAILED);
   }

   g_position_states.Clear(true);

   g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   ResetDailyStats();
   ResetWeeklyStats();

   EventSetTimer(5);

   Print("[Init] APlus Gold EA initialized successfully.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_handle_fast != INVALID_HANDLE)
      IndicatorRelease(g_handle_fast);
   if(g_handle_slow != INVALID_HANDLE)
      IndicatorRelease(g_handle_slow);

   ObjectDelete(0, g_panel_name);

   g_position_states.Clear(true);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateEquityStats();
   CheckRiskLimits();
   ManageOpenPositions();
   RefreshPanel();

   if(!IsTradeAllowed())
      return;

   if(InpEnableSessionFilter && !IsWithinSession())
      return;

   if(InpEnableNewsFilter && !NewsFilterAllows())
      return;

   if(InpEnableDXYFilter && !DXYFilterAllows())
      return;

   if(PositionsTotalByMagic() > 0)
      return; // No pyramiding

   TrendBias trend = GetTrendBias();
   if(trend == TREND_NONE)
      return;

   double entry_price = 0.0;
   double stop_loss = 0.0;
   double take_profit = 0.0;
   double partial_tp = 0.0;
   double risk_points = 0.0;

   if(!GetEntrySignal(trend, entry_price, stop_loss, take_profit, partial_tp, risk_points))
      return;

   double volume = CalculateVolume(risk_points);
   if(volume <= 0.0)
   {
      Print("[Trade] Volume calculation failed or below minimum.");
      return;
   }

   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);

   bool result = false;
   if(trend == TREND_BULL)
   {
      result = g_trade.Buy(volume, _Symbol, 0.0, stop_loss, take_profit, InpTradeComment);
   }
   else if(trend == TREND_BEAR)
   {
      result = g_trade.Sell(volume, _Symbol, 0.0, stop_loss, take_profit, InpTradeComment);
   }

   if(result)
   {
      g_trades_today++;
      PrintFormat("[Trade] %s order placed. Volume=%.2f SL=%.2f TP=%.2f Partial=%.2f", trend == TREND_BULL ? "Buy" : "Sell", volume, stop_loss, take_profit, partial_tp);
   }
   else
   {
      PrintFormat("[Trade] OrderSend failed: %d", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.magic != (long)InpMagicNumber)
         return;

      if(!HistoryDealSelect(trans.deal))
         return;

      int entry_type = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

      if(entry_type == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                         HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) +
                         HistoryDealGetDouble(trans.deal, DEAL_SWAP);

         bool position_open = PositionSelectByTicket(trans.position);

         if(!position_open)
         {
            RemovePositionState(trans.position);

            if(profit < 0.0)
               g_consecutive_losses++;
            else
               g_consecutive_losses = 0;

            PrintFormat("[Trade] Position %I64u closed. Profit=%.2f, ConsecutiveLosses=%d", trans.position, profit, g_consecutive_losses);
         }
         else
         {
            PrintFormat("[Trade] Position %I64u partial close. Realized=%.2f", trans.position, profit);
         }
      }
      else if(entry_type == DEAL_ENTRY_IN)
      {
         // Initial state tracking
         GetPositionState(trans.position, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer handler: refresh panel                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   RefreshPanel();
}

//+------------------------------------------------------------------+
//| Reset daily stats                                                |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   g_daily_reset_gmt = TimeGMT();
   g_daily_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_trades_today = 0;
   g_daily_disabled = false;
}

//+------------------------------------------------------------------+
//| Reset weekly stats                                               |
//+------------------------------------------------------------------+
void ResetWeeklyStats()
{
   g_weekly_reset_gmt = TimeGMT();
   g_weekly_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_weekly_disabled = false;
}

//+------------------------------------------------------------------+
//| Update equity statistics                                         |
//+------------------------------------------------------------------+
void UpdateEquityStats()
{
   datetime now_gmt = TimeGMT();

   MqlDateTime dt_now;
   TimeToStruct(now_gmt, dt_now);

   MqlDateTime dt_daily;
   TimeToStruct(g_daily_reset_gmt, dt_daily);

   if(dt_now.year != dt_daily.year || dt_now.yday != dt_daily.yday)
      ResetDailyStats();

   if(g_weekly_reset_gmt == 0 || now_gmt - g_weekly_reset_gmt >= 7 * 24 * 60 * 60)
      ResetWeeklyStats();

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peak_equity)
      g_peak_equity = equity;

   double drawdown = 0.0;
   if(g_peak_equity > 0.0)
      drawdown = (g_peak_equity - equity) / g_peak_equity * 100.0;

}

//+------------------------------------------------------------------+
//| Check risk limits                                                |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   double daily_pl = GetDailyPLPercent();
   double weekly_pl = GetWeeklyPLPercent();
   double dd_percent = GetDrawdownPercent();

   if(daily_pl <= -MathAbs(InpMaxDailyLossPercent))
   {
      if(!g_daily_disabled)
         Print("[Risk] Daily loss limit reached. Trading disabled until next UTC day.");
      g_daily_disabled = true;
   }

   if(weekly_pl <= -MathAbs(InpMaxWeeklyLossPercent))
   {
      if(!g_weekly_disabled)
         Print("[Risk] Weekly loss limit reached. Trading disabled until next week.");
      g_weekly_disabled = true;
   }

   if(dd_percent >= MathAbs(InpHardDrawdownPercent))
   {
      if(!g_hard_dd_triggered)
      {
         Print("[Risk] Hard drawdown limit reached. Trading halted.");
         if(InpCloseOnHardDrawdown)
            CloseAllPositions();
      }
      g_hard_dd_triggered = true;
   }
}

//+------------------------------------------------------------------+
//| Session filter                                                   |
//+------------------------------------------------------------------+
bool IsWithinSession()
{
   datetime now_gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(now_gmt, dt);

   int hour = dt.hour;
   if(InpSessionStartHourUTC <= InpSessionEndHourUTC)
      return(hour >= InpSessionStartHourUTC && hour < InpSessionEndHourUTC);

   // Overnight sessions (wrap around midnight)
   if(hour >= InpSessionStartHourUTC || hour < InpSessionEndHourUTC)
      return(true);

   return(false);
}

//+------------------------------------------------------------------+
//| Allowed symbol check                                             |
//+------------------------------------------------------------------+
bool IsAllowedSymbol(const string symbol)
{
   string list = StringUpper(InpAllowedSymbols);
   string symb = StringUpper(symbol);

   StringReplace(list, " ", "");

   int pos = StringFind(list, symb);
   if(pos == -1)
      return(false);

   // Ensure exact match within comma-separated list
   bool start_ok = (pos == 0) || (StringGetCharacter(list, pos - 1) == ',');
   int end_index = pos + StringLen(symb);
   bool end_ok = (end_index == StringLen(list)) || (StringGetCharacter(list, end_index) == ',');

   return(start_ok && end_ok);
}

//+------------------------------------------------------------------+
//| Placeholder news filter                                          |
//+------------------------------------------------------------------+
bool NewsFilterAllows()
{
   static datetime last_warning = 0;
   datetime now = TimeCurrent();
   if(now - last_warning > 300)
   {
      Print("[Filter] News filter enabled but not implemented. Blocking trades.");
      last_warning = now;
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Placeholder DXY filter                                           |
//+------------------------------------------------------------------+
bool DXYFilterAllows()
{
   static datetime last_warning = 0;
   datetime now = TimeCurrent();
   if(now - last_warning > 300)
   {
      Print("[Filter] DXY filter enabled but not implemented. Blocking trades.");
      last_warning = now;
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Positions by magic                                               |
//+------------------------------------------------------------------+
int PositionsTotalByMagic()
{
   int total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i))
         continue;

      string pos_symbol = PositionGetString(POSITION_SYMBOL);
      if(pos_symbol != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         total++;
   }
   return(total);
}

//+------------------------------------------------------------------+
//| Trend bias from higher timeframe EMAs                            |
//+------------------------------------------------------------------+
TrendBias GetTrendBias()
{
   double fast[2];
   double slow[2];
   if(CopyBuffer(g_handle_fast, 0, 1, 2, fast) != 2)
      return(TREND_NONE);
   if(CopyBuffer(g_handle_slow, 0, 1, 2, slow) != 2)
      return(TREND_NONE);

   double fast_val = fast[1];
   double slow_val = slow[1];

   if(fast_val > slow_val)
      return(TREND_BULL);
   if(fast_val < slow_val)
      return(TREND_BEAR);

   return(TREND_NONE);
}

//+------------------------------------------------------------------+
//| Entry signal detection                                           |
//+------------------------------------------------------------------+
bool GetEntrySignal(TrendBias trend, double &entry_price, double &stop_loss, double &take_profit, double &partial_tp, double &risk_points)
{
   if(trend == TREND_NONE)
      return(false);

   if(!DetectEngulfing(trend))
      return(false);

   double swing_high = 0.0;
   double swing_low = 0.0;

   if(!FindSwingLevels(trend == TREND_BULL, swing_high, swing_low))
      return(false);

   double fib_level = 0.0;
   if(trend == TREND_BULL)
   {
      double range = swing_high - swing_low;
      if(range <= 0.0)
         return(false);
      fib_level = swing_high - range * 0.618;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   else
   {
      double range = swing_high - swing_low;
      if(range <= 0.0)
         return(false);
      fib_level = swing_low + range * 0.618;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }

   if(entry_price <= 0.0)
      return(false);

   double tolerance = InpFibTolerancePoints * _Point;
   if(MathAbs(entry_price - fib_level) > tolerance)
      return(false);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double min_stop = InpMinimumStopPoints * _Point;

   if(trend == TREND_BULL)
   {
      stop_loss = swing_low;
      if((entry_price - stop_loss) < min_stop)
         stop_loss = entry_price - min_stop;

      risk_points = (entry_price - stop_loss) / _Point;
      take_profit = entry_price + risk_points * _Point * InpRewardRiskMain;
      partial_tp = entry_price + risk_points * _Point * InpPartialCloseRR;
   }
   else
   {
      stop_loss = swing_high;
      if((stop_loss - entry_price) < min_stop)
         stop_loss = entry_price + min_stop;

      risk_points = (stop_loss - entry_price) / _Point;
      take_profit = entry_price - risk_points * _Point * InpRewardRiskMain;
      partial_tp = entry_price - risk_points * _Point * InpPartialCloseRR;
   }

   if(risk_points <= 0.0)
      return(false);

   stop_loss = NormalizeDouble(stop_loss, digits);
   take_profit = NormalizeDouble(take_profit, digits);
   partial_tp = NormalizeDouble(partial_tp, digits);
   entry_price = NormalizeDouble(entry_price, digits);

   return(true);
}

//+------------------------------------------------------------------+
//| Engulfing pattern detection                                      |
//+------------------------------------------------------------------+
bool DetectEngulfing(TrendBias trend)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpEntryTimeframe, 1, 3, rates) != 3)
      return(false);

   MqlRates current = rates[0];
   MqlRates previous = rates[1];

   if(trend == TREND_BULL)
   {
      if(previous.close >= previous.open)
         return(false);
      if(current.close <= current.open)
         return(false);

      bool engulf = (current.close >= previous.open) && (current.open <= previous.close);
      if(!engulf)
         return(false);

      return(true);
   }
   else if(trend == TREND_BEAR)
   {
      if(previous.close <= previous.open)
         return(false);
      if(current.close >= current.open)
         return(false);

      bool engulf = (current.close <= previous.open) && (current.open >= previous.close);
      if(!engulf)
         return(false);

      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Find swing levels using fractal logic                            |
//+------------------------------------------------------------------+
bool FindSwingLevels(bool bullish, double &swing_high, double &swing_low)
{
   const int lookback = 80;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpEntryTimeframe, 1, lookback, rates) != lookback)
      return(false);

   int primary_index = -1;
   int secondary_index = -1;

   for(int i = 2; i < lookback - 2; i++)
   {
      bool is_high = rates[i].high > rates[i - 1].high && rates[i].high > rates[i - 2].high &&
                     rates[i].high > rates[i + 1].high && rates[i].high > rates[i + 2].high;
      bool is_low  = rates[i].low < rates[i - 1].low && rates[i].low < rates[i - 2].low &&
                     rates[i].low < rates[i + 1].low && rates[i].low < rates[i + 2].low;

      if(bullish)
      {
         if(primary_index == -1 && is_high)
         {
            primary_index = i;
            continue;
         }
         if(primary_index != -1 && is_low && i > primary_index)
         {
            secondary_index = i;
            break;
         }
      }
      else
      {
         if(primary_index == -1 && is_low)
         {
            primary_index = i;
            continue;
         }
         if(primary_index != -1 && is_high && i > primary_index)
         {
            secondary_index = i;
            break;
         }
      }
   }

   if(primary_index == -1 || secondary_index == -1)
      return(false);

   if(bullish)
   {
      swing_high = rates[primary_index].high;
      swing_low = rates[secondary_index].low;
   }
   else
   {
      swing_low = rates[primary_index].low;
      swing_high = rates[secondary_index].high;
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Volume calculation                                               |
//+------------------------------------------------------------------+
double CalculateVolume(double stop_points)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * MathAbs(InpRiskPerTrade) / 100.0;

   if(risk_amount <= 0.0 || stop_points <= 0.0)
      return(0.0);

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tick_value <= 0.0 || tick_size <= 0.0)
      return(0.0);

   double value_per_point_per_lot = (tick_value / tick_size) * _Point;
   double risk_per_lot = stop_points * value_per_point_per_lot;

   if(risk_per_lot <= 0.0)
      return(0.0);

   double volume = risk_amount / risk_per_lot;

   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lot_step <= 0.0)
      lot_step = min_lot;

   if(volume < min_lot)
      volume = min_lot;
   if(volume > max_lot)
      volume = max_lot;

   volume = MathFloor((volume + lot_step * 0.5) / lot_step) * lot_step;

   if(volume < min_lot)
      volume = min_lot;
   if(volume > max_lot)
      volume = max_lot;

   volume = NormalizeDouble(volume, (int)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME_DIGITS));

   return(volume);
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i))
         continue;

      string pos_symbol = PositionGetString(POSITION_SYMBOL);
      if(pos_symbol != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double stop_loss = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      double tp_price = PositionGetDouble(POSITION_TP);

      double risk_points = 0.0;

      if(type == POSITION_TYPE_BUY)
         risk_points = (open_price - stop_loss) / _Point;
      else if(type == POSITION_TYPE_SELL)
         risk_points = (stop_loss - open_price) / _Point;

      if(risk_points <= 0.0)
         continue;

      HandlePositionState(ticket);

      CPositionState *state = GetPositionState(ticket, true);
      if(state == NULL)
         continue;

      double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double profit_distance = (type == POSITION_TYPE_BUY) ? (current_price - open_price)
                                                           : (open_price - current_price);

      double rr = profit_distance / (risk_points * _Point);

      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      // Break-even adjustment
      if(InpEnableBreakEven && !state->breakeven_done && rr >= InpBreakEvenRR)
      {
         double new_sl = (type == POSITION_TYPE_BUY) ? open_price + (_Point * 2.0)
                                                     : open_price - (_Point * 2.0);

         new_sl = NormalizeDouble(new_sl, digits);

         if(g_trade.PositionModify(ticket, new_sl, tp_price))
         {
            state->breakeven_done = true;
            PrintFormat("[Manage] Position %I64u moved to break-even at %.2f", ticket, new_sl);
         }
      }

      // Partial close
      if(!state->partial_done && rr >= InpPartialCloseRR && InpPartialClosePercent > 0.0)
      {
         double close_volume = volume * (InpPartialClosePercent / 100.0);
         double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         close_volume = MathFloor(close_volume / step_vol) * step_vol;
         if(close_volume >= min_vol && close_volume < volume)
         {
            if(g_trade.PositionClosePartial(ticket, close_volume))
            {
               state->partial_done = true;
               PrintFormat("[Manage] Partial close %.2f lots on position %I64u", close_volume, ticket);
            }
         }
      }

      // Trailing stop
      if(InpEnableTrailing && rr >= InpTrailingStartRR)
      {
         double desired_sl = 0.0;
         double step_price = InpTrailingStepPoints * _Point;

         if(type == POSITION_TYPE_BUY)
            desired_sl = current_price - step_price;
         else
            desired_sl = current_price + step_price;

         desired_sl = NormalizeDouble(desired_sl, digits);

         double current_sl = PositionGetDouble(POSITION_SL);

         if((type == POSITION_TYPE_BUY && desired_sl > current_sl && desired_sl > state->last_trail_price) ||
            (type == POSITION_TYPE_SELL && desired_sl < current_sl && desired_sl < state->last_trail_price))
         {
            if(g_trade.PositionModify(ticket, desired_sl, tp_price))
            {
               state->last_trail_price = desired_sl;
               PrintFormat("[Manage] Trailing stop adjusted for position %I64u to %.2f", ticket, desired_sl);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Ensure position state exists                                     |
//+------------------------------------------------------------------+
void HandlePositionState(ulong ticket)
{
   CPositionState *state = GetPositionState(ticket, true);
   if(state == NULL)
      return;

   if(state->last_trail_price == 0.0)
   {
      double sl = PositionGetDouble(POSITION_SL);
      state->last_trail_price = sl;
   }
}

//+------------------------------------------------------------------+
//| Retrieve or create position state                                |
//+------------------------------------------------------------------+
CPositionState* GetPositionState(const ulong ticket, const bool create_if_missing)
{
   for(int i = 0; i < g_position_states.Total(); i++)
   {
      CPositionState *state = (CPositionState*)g_position_states.At(i);
      if(CheckPointer(state) && state->ticket == ticket)
         return(state);
   }

   if(!create_if_missing)
      return(NULL);

   CPositionState *state = new CPositionState();
   if(state == NULL)
      return(NULL);

   state->ticket = ticket;
   g_position_states.Add(state);
   return(state);
}

//+------------------------------------------------------------------+
//| Remove position state                                            |
//+------------------------------------------------------------------+
void RemovePositionState(const ulong ticket)
{
   for(int i = g_position_states.Total() - 1; i >= 0; i--)
   {
      CPositionState *state = (CPositionState*)g_position_states.At(i);
      if(!CheckPointer(state))
         continue;
      if(state->ticket == ticket)
      {
         delete state;
         g_position_states.Delete(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Refresh on-chart panel                                           |
//+------------------------------------------------------------------+
void RefreshPanel()
{
   if(ObjectFind(0, g_panel_name) < 0)
   {
      ObjectCreate(0, g_panel_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, g_panel_name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, g_panel_name, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, g_panel_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, g_panel_name, OBJPROP_FONTSIZE, InpPanelFontSize);
      ObjectSetString(0, g_panel_name, OBJPROP_FONT, InpPanelFont);
      ObjectSetInteger(0, g_panel_name, OBJPROP_COLOR, clrWhite);
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = GetDrawdownPercent();
   double daily_pl = GetDailyPLPercent();
   double weekly_pl = GetWeeklyPLPercent();
   int open_trades = PositionsTotalByMagic();
   string trend_text = "Neutral";
   TrendBias trend = GetTrendBias();
   if(trend == TREND_BULL)
      trend_text = "Bullish";
   else if(trend == TREND_BEAR)
      trend_text = "Bearish";

   string text = StringFormat("Balance: %.2f\nEquity: %.2f\nDrawdown: %.2f%%\nDaily P/L: %.2f%%\nWeekly P/L: %.2f%%\nOpen trades: %d\nRisk/Trade: %.2f%%\nTrend: %s\nConsec Losses: %d",
                              balance,
                              equity,
                              dd,
                              daily_pl,
                              weekly_pl,
                              open_trades,
                              InpRiskPerTrade,
                              trend_text,
                              g_consecutive_losses);

   ObjectSetString(0, g_panel_name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i))
         continue;

      string pos_symbol = PositionGetString(POSITION_SYMBOL);
      if(pos_symbol != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      g_trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| Get daily P/L percent                                            |
//+------------------------------------------------------------------+
double GetDailyPLPercent()
{
   if(g_daily_start_equity <= 0.0)
      return(0.0);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return((equity - g_daily_start_equity) / g_daily_start_equity * 100.0);
}

//+------------------------------------------------------------------+
//| Get weekly P/L percent                                           |
//+------------------------------------------------------------------+
double GetWeeklyPLPercent()
{
   if(g_weekly_start_equity <= 0.0)
      return(0.0);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return((equity - g_weekly_start_equity) / g_weekly_start_equity * 100.0);
}

//+------------------------------------------------------------------+
//| Drawdown percent                                                 |
//+------------------------------------------------------------------+
double GetDrawdownPercent()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peak_equity <= 0.0)
      return(0.0);

   return((g_peak_equity - equity) / g_peak_equity * 100.0);
}

//+------------------------------------------------------------------+
//| Utility to check trading permission                              |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ENABLED))
      return(false);

   if(g_daily_disabled || g_weekly_disabled || g_hard_dd_triggered)
      return(false);

   if(InpMaxConsecutiveLosses > 0 && g_consecutive_losses >= InpMaxConsecutiveLosses)
      return(false);

   if(InpMaxTradesPerDay > 0 && g_trades_today >= InpMaxTradesPerDay)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| Usage guide (comment only)                                       |
//+------------------------------------------------------------------+
// Recommended setup:
// - Attach to XAUUSD chart on M15 or higher. Entry logic uses M15 data; trend filter uses configurable timeframe (default H1).
// - Default parameters target prop-firm risk controls. Adjust % risk and prop limits to match rules.
// - Backtesting: use MT5 Strategy Tester with "Every tick based on real ticks". Ensure sufficient history for EMA & swing calculations.
// - Monitor Experts tab for detailed logs: trade actions, risk state changes, panel updates.
// - Panel displays current balance, equity, drawdown, daily P/L, open trades, risk per trade, and trend bias.
// - For partial close, break-even, trailing, the EA manages orders automatically. Ensure broker allows partial closes and trailing stops.
// - News/DXY filters are placeholders; integrate external data feed for production use if needed.

