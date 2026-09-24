//+------------------------------------------------------------------+
//|                                               TrendPulse_EA.mq5 |
//|  Trading bot version of the TrendPulse indicator.                |
//|  Signal logic lives in Include/TrendPulse/TrendPulseCore.mqh     |
//|  so the EA opens trades exactly where the indicator draws arrows.|
//+------------------------------------------------------------------+
#property copyright "TrendPulse"
#property version   "1.00"
#property description "EMA crossover + trend + RSI filter EA with ATR SL/TP, risk sizing, breakeven & trailing"

#include <Trade/Trade.mqh>
#include <TrendPulse/TrendPulseCore.mqh>

enum ENUM_LOT_MODE
  {
   LOT_FIXED   = 0,  // Fixed lots
   LOT_RISK_PC = 1   // Risk % of balance per trade
  };

input group "=== Money management ==="
input ENUM_LOT_MODE InpLotMode      = LOT_RISK_PC;  // Lot sizing mode
input double        InpFixedLots    = 0.10;         // Fixed lots
input double        InpRiskPercent  = 1.0;          // Risk % per trade

input group "=== Trade management ==="
input bool   InpCloseOnOpposite = true;   // Close position on opposite signal
input bool   InpUseBreakeven    = true;   // Move SL to breakeven
input double InpBeTriggerAtr    = 1.0;    // Breakeven trigger (x ATR in profit)
input int    InpBeLockPoints    = 10;     // Points locked in at breakeven
input bool   InpUseTrailing     = true;   // Use ATR trailing stop
input double InpTrailStartAtr   = 1.5;    // Start trailing after (x ATR in profit)
input double InpTrailAtrMult    = 1.0;    // Trailing distance (x ATR)

input group "=== Filters ==="
input int    InpMaxSpreadPoints = 30;     // Max spread in points (0 = off)
input bool   InpUseTimeFilter   = false;  // Trade only between hours (server time)
input int    InpStartHour       = 8;      // Start hour (0-23)
input int    InpEndHour         = 20;     // End hour (0-23, exclusive)

input group "=== General ==="
input ulong  InpMagic           = 20260924; // Magic number
input int    InpSlippagePoints  = 20;       // Max slippage (points)
input string InpComment         = "TrendPulse"; // Order comment

CTrade   trade;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!TP_Init(_Symbol, _Period))
      return(INIT_FAILED);

   if(InpLotMode == LOT_FIXED && InpFixedLots <= 0.0)
     {
      Print("TrendPulse EA: fixed lots must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLotMode == LOT_RISK_PC && (InpRiskPercent <= 0.0 || InpRiskPercent > 100.0))
     {
      Print("TrendPulse EA: risk % must be between 0 and 100");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpStartHour < 0 || InpStartHour > 23 || InpEndHour < 0 || InpEndHour > 23)
     {
      Print("TrendPulse EA: hours must be between 0 and 23");
      return(INIT_PARAMETERS_INCORRECT);
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   // Only act on signals that appear after the EA is attached
   g_lastBarTime = iTime(_Symbol, _Period, 0);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   TP_Deinit();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   //--- manage open positions on every tick
   double atrNow;
   if(TP_GetAtr(1, atrNow) && atrNow > 0.0)
      ManagePositions(atrNow);

   //--- signals are evaluated once per new bar, on the last closed bar
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;

   int    signal;
   double atr;
   if(!TP_GetSignal(1, signal, atr))
      return;                      // data not ready - retry on next tick
   g_lastBarTime = barTime;

   if(signal == TP_NONE || atr <= 0.0)
      return;

   ENUM_POSITION_TYPE wanted   = (signal == TP_BUY) ? POSITION_TYPE_BUY  : POSITION_TYPE_SELL;
   ENUM_POSITION_TYPE opposite = (signal == TP_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   if(InpCloseOnOpposite)
      ClosePositions(opposite);

   if(CountPositions(wanted) > 0 || CountPositions(opposite) > 0)
      return;                      // one position at a time

   if(!FiltersPass())
      return;

   OpenTrade(signal, atr);
  }

//+------------------------------------------------------------------+
//| Spread and session filters                                       |
//+------------------------------------------------------------------+
bool FiltersPass()
  {
   if(InpMaxSpreadPoints > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpreadPoints)
        {
         PrintFormat("TrendPulse EA: spread %d > max %d, signal skipped", (int)spread, InpMaxSpreadPoints);
         return(false);
        }
     }

   if(InpUseTimeFilter)
     {
      MqlDateTime t;
      TimeToStruct(TimeCurrent(), t);
      bool inside;
      if(InpStartHour <= InpEndHour)
         inside = (t.hour >= InpStartHour && t.hour < InpEndHour);
      else   // session crosses midnight, e.g. 22 -> 6
         inside = (t.hour >= InpStartHour || t.hour < InpEndHour);
      if(!inside)
        {
         Print("TrendPulse EA: outside trading hours, signal skipped");
         return(false);
        }
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Open a market order with ATR-based SL/TP                         |
//+------------------------------------------------------------------+
void OpenTrade(const int signal, const double atr)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double slDist  = MathMax(atr * InpSlAtrMult, minDist);
   double tpDist  = MathMax(atr * InpTpAtrMult, minDist);

   double price, sl, tp;
   ENUM_ORDER_TYPE type;
   if(signal == TP_BUY)
     {
      type  = ORDER_TYPE_BUY;
      price = tick.ask;
      sl    = price - slDist;
      tp    = price + tpDist;
     }
   else
     {
      type  = ORDER_TYPE_SELL;
      price = tick.bid;
      sl    = price + slDist;
      tp    = price - tpDist;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lots = CalcLots(type, price, sl);
   if(lots <= 0.0)
      return;

   double margin;
   if(OrderCalcMargin(type, _Symbol, lots, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      PrintFormat("TrendPulse EA: not enough free margin for %.2f lots", lots);
      return;
     }

   bool ok = (type == ORDER_TYPE_BUY)
             ? trade.Buy(lots, _Symbol, price, sl, tp, InpComment)
             : trade.Sell(lots, _Symbol, price, sl, tp, InpComment);

   if(!ok || (trade.ResultRetcode() != TRADE_RETCODE_DONE &&
              trade.ResultRetcode() != TRADE_RETCODE_PLACED))
      PrintFormat("TrendPulse EA: order failed, retcode %u (%s)",
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//| Lot size: fixed, or sized so hitting SL loses InpRiskPercent     |
//+------------------------------------------------------------------+
double CalcLots(const ENUM_ORDER_TYPE type, const double price, const double sl)
  {
   double lots;
   if(InpLotMode == LOT_FIXED)
      lots = InpFixedLots;
   else
     {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double lossPerLot = 0.0;

      // exact loss of 1 lot from entry to SL, in account currency
      if(OrderCalcProfit(type, _Symbol, 1.0, price, sl, lossPerLot))
         lossPerLot = MathAbs(lossPerLot);

      if(lossPerLot <= 0.0)   // fallback via tick value
        {
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickValue <= 0.0 || tickSize <= 0.0)
            return(0.0);
         lossPerLot = MathAbs(price - sl) / tickSize * tickValue;
        }
      if(lossPerLot <= 0.0)
         return(0.0);
      lots = riskMoney / lossPerLot;
     }
   return(NormalizeLots(lots));
  }

//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      step = 0.01;

   lots = MathFloor(lots / step + 1e-9) * step;
   if(lots < vmin)
     {
      PrintFormat("TrendPulse EA: calculated lot %.4f below broker minimum %.2f - trade skipped "
                  "(increase risk %% or balance)", lots, vmin);
      return(0.0);
     }
   lots = MathMin(lots, vmax);

   int digits = (int)MathMax(0.0, MathCeil(-MathLog10(step)));
   return(NormalizeDouble(lots, digits));
  }

//+------------------------------------------------------------------+
//| Count this EA's positions of a given type on this symbol         |
//+------------------------------------------------------------------+
int CountPositions(const ENUM_POSITION_TYPE type)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         count++;
     }
   return(count);
  }

//+------------------------------------------------------------------+
//| Close this EA's positions of a given type on this symbol         |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;

      if(!trade.PositionClose(ticket))
         PrintFormat("TrendPulse EA: failed to close #%I64u, retcode %u",
                     ticket, trade.ResultRetcode());
     }
  }

//+------------------------------------------------------------------+
//| Breakeven and ATR trailing stop                                  |
//+------------------------------------------------------------------+
void ManagePositions(const double atr)
  {
   if(!InpUseBreakeven && !InpUseTrailing)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double newSl = sl;

      if(type == POSITION_TYPE_BUY)
        {
         double profit = tick.bid - open;
         if(InpUseBreakeven && profit >= atr * InpBeTriggerAtr)
           {
            double be = open + InpBeLockPoints * _Point;
            if(newSl < be) newSl = be;
           }
         if(InpUseTrailing && profit >= atr * InpTrailStartAtr)
           {
            double trail = tick.bid - atr * InpTrailAtrMult;
            if(trail > newSl) newSl = trail;
           }
         newSl = NormalizeDouble(newSl, _Digits);
         if(newSl > sl + _Point && tick.bid - newSl >= minDist)
            if(!trade.PositionModify(ticket, newSl, tp))
               PrintFormat("TrendPulse EA: modify #%I64u failed, retcode %u", ticket, trade.ResultRetcode());
        }
      else // SELL
        {
         double profit = open - tick.ask;
         if(InpUseBreakeven && profit >= atr * InpBeTriggerAtr)
           {
            double be = open - InpBeLockPoints * _Point;
            if(newSl == 0.0 || newSl > be) newSl = be;
           }
         if(InpUseTrailing && profit >= atr * InpTrailStartAtr)
           {
            double trail = tick.ask + atr * InpTrailAtrMult;
            if(newSl == 0.0 || trail < newSl) newSl = trail;
           }
         newSl = NormalizeDouble(newSl, _Digits);
         if(newSl > 0.0 && (sl == 0.0 || newSl < sl - _Point) && newSl - tick.ask >= minDist)
            if(!trade.PositionModify(ticket, newSl, tp))
               PrintFormat("TrendPulse EA: modify #%I64u failed, retcode %u", ticket, trade.ResultRetcode());
        }
     }
  }
//+------------------------------------------------------------------+
