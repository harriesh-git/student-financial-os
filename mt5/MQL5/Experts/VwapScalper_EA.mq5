//+------------------------------------------------------------------+
//|                                              VwapScalper_EA.mq5 |
//|  VWAP + EMA pullback scalper. Trades exactly the arrows drawn by |
//|  VwapScalper_Indicator (shared logic in VwapScalperCore.mqh).    |
//|  Recommended: M5 (or M1/M3), liquid symbol, London/NY session.   |
//+------------------------------------------------------------------+
#property copyright "VwapScalper"
#property version   "1.00"
#property description "Session VWAP trend + EMA pullback scalper with R-based exits and daily risk limits"

#include <Trade/Trade.mqh>
#include <VwapScalper/VwapScalperCore.mqh>

enum ENUM_LOT_MODE
  {
   LOT_FIXED   = 0,  // Fixed lots
   LOT_RISK_PC = 1   // Risk % of balance per trade
  };

input group "=== Money management ==="
input ENUM_LOT_MODE InpLotMode      = LOT_RISK_PC;  // Lot sizing mode
input double        InpFixedLots    = 0.10;         // Fixed lots
input double        InpRiskPercent  = 0.5;          // Risk % per trade

input group "=== Trade management ==="
input double InpBeAtR              = 1.0;   // Move SL to breakeven at this many R in profit (0 = off)
input int    InpBeLockPoints       = 5;     // Points locked in at breakeven
input int    InpMaxBarsInTrade     = 12;    // Time stop: close after N bars (0 = off)
input bool   InpExitOnVwapCross    = true;  // Close if a bar closes on the wrong side of VWAP
input bool   InpCloseOutsideSession= true;  // Close positions when session ends
input bool   InpCloseAtVwapReset   = true;  // Close positions when VWAP resets (new day)

input group "=== Daily risk limits ==="
input int    InpMaxTradesPerDay    = 6;     // Max new trades per day (0 = unlimited)
input double InpMaxDailyLossPct    = 2.0;   // Stop trading for the day after this % loss (0 = off)

input group "=== Filters ==="
input int    InpMaxSpreadPoints    = 20;    // Max spread in points (0 = off)

input group "=== General ==="
input ulong  InpMagic              = 20260925;     // Magic number
input int    InpSlippagePoints     = 10;           // Max slippage (points)
input string InpComment            = "VwapScalper";// Order comment

CTrade   trade;
datetime g_lastBarTime = 0;

//--- data window (oldest -> newest)
int      g_n = 0;
datetime W_time[];
double   W_open[], W_high[], W_low[], W_close[];
long     W_tvol[], W_rvol[];
double   W_fast[], W_slow[], W_atr[];
double   W_cumPV[], W_cumV[], W_cumP2V[], W_sessBar[], W_vwap[], W_sd[];

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!VS_Init(_Symbol, _Period))
      return(INIT_FAILED);

   if(PeriodSeconds(_Period) > PeriodSeconds(PERIOD_H1))
      Print("VwapScalper EA: warning - session VWAP is meant for intraday charts (M1-M15 recommended)");

   if(InpLotMode == LOT_FIXED && InpFixedLots <= 0.0)
     { Print("VwapScalper EA: fixed lots must be > 0"); return(INIT_PARAMETERS_INCORRECT); }
   if(InpLotMode == LOT_RISK_PC && (InpRiskPercent <= 0.0 || InpRiskPercent > 100.0))
     { Print("VwapScalper EA: risk % must be between 0 and 100"); return(INIT_PARAMETERS_INCORRECT); }

   // window must hold more than one full VWAP session plus indicator warm-up
   g_n = (int)(2 * 86400 / PeriodSeconds(_Period)) + VS_MinBars() + 10;
   g_n = MathMin(g_n, 6000);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_lastBarTime = iTime(_Symbol, _Period, 0);   // only trade fresh signals
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   VS_Deinit();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   ManagePositions();

   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;
   if(!LoadWindow())
      return;                       // data not ready - retry next tick
   g_lastBarTime = barTime;

   int i = g_n - 2;                 // last closed bar

   if(InpExitOnVwapCross)
      VwapCrossExit(i);

   int sig = VS_Evaluate(i, W_time, W_open, W_high, W_low, W_close,
                         W_fast, W_slow, W_atr, W_vwap, W_sessBar);
   if(sig == VS_NONE)
      return;

   if(CountPositions() > 0)
      return;                       // one trade at a time
   if(!DailyLimitsOk() || !SpreadOk())
      return;

   OpenTrade(sig, i);
  }

//+------------------------------------------------------------------+
//| Copy the last g_n bars and build session VWAP (shared step)      |
//+------------------------------------------------------------------+
bool LoadWindow()
  {
   int n = g_n;
   if(Bars(_Symbol, _Period) < n || !VS_HandlesReady(n))
      return(false);

   if(CopyTime(_Symbol, _Period, 0, n, W_time)   != n) return(false);
   if(CopyOpen(_Symbol, _Period, 0, n, W_open)   != n) return(false);
   if(CopyHigh(_Symbol, _Period, 0, n, W_high)   != n) return(false);
   if(CopyLow(_Symbol, _Period, 0, n, W_low)     != n) return(false);
   if(CopyClose(_Symbol, _Period, 0, n, W_close) != n) return(false);
   if(CopyTickVolume(_Symbol, _Period, 0, n, W_tvol) != n) return(false);
   if(CopyRealVolume(_Symbol, _Period, 0, n, W_rvol) != n)
     {
      ArrayResize(W_rvol, n);
      ArrayInitialize(W_rvol, 0);   // symbol has no real volume
     }
   if(CopyBuffer(VS_hFast, 0, 0, n, W_fast) != n) return(false);
   if(CopyBuffer(VS_hSlow, 0, 0, n, W_slow) != n) return(false);
   if(CopyBuffer(VS_hAtr,  0, 0, n, W_atr)  != n) return(false);

   ArrayResize(W_cumPV, n);
   ArrayResize(W_cumV, n);
   ArrayResize(W_cumP2V, n);
   ArrayResize(W_sessBar, n);
   ArrayResize(W_vwap, n);
   ArrayResize(W_sd, n);

   for(int i = 0; i < n; i++)
      VS_VwapStep(i, W_time, W_high, W_low, W_close, VS_Volume(W_tvol[i], W_rvol[i]),
                  W_cumPV, W_cumV, W_cumP2V, W_sessBar, W_vwap, W_sd);
   return(true);
  }

//+------------------------------------------------------------------+
void OpenTrade(const int sig, const int i)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   ENUM_ORDER_TYPE type = (sig == VS_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entry = (sig == VS_BUY) ? tick.ask : tick.bid;

   double sl, tp;
   if(!VS_Levels(sig, entry, W_high[i], W_low[i], W_atr[i], sl, tp))
      return;

   // respect broker minimum stop distance
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(MathAbs(entry - sl) < minDist || MathAbs(tp - entry) < minDist)
     {
      Print("VwapScalper EA: SL/TP closer than broker stop level, signal skipped");
      return;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lots = CalcLots(type, entry, sl);
   if(lots <= 0.0)
      return;

   double margin;
   if(OrderCalcMargin(type, _Symbol, lots, entry, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      PrintFormat("VwapScalper EA: not enough free margin for %.2f lots", lots);
      return;
     }

   bool ok = (type == ORDER_TYPE_BUY)
             ? trade.Buy(lots, _Symbol, entry, sl, tp, InpComment)
             : trade.Sell(lots, _Symbol, entry, sl, tp, InpComment);
   if(!ok || (trade.ResultRetcode() != TRADE_RETCODE_DONE &&
              trade.ResultRetcode() != TRADE_RETCODE_PLACED))
      PrintFormat("VwapScalper EA: order failed, retcode %u (%s)",
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
double CalcLots(const ENUM_ORDER_TYPE type, const double price, const double sl)
  {
   double lots;
   if(InpLotMode == LOT_FIXED)
      lots = InpFixedLots;
   else
     {
      double riskMoney  = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double lossPerLot = 0.0;
      if(OrderCalcProfit(type, _Symbol, 1.0, price, sl, lossPerLot))
         lossPerLot = MathAbs(lossPerLot);
      if(lossPerLot <= 0.0)
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

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   lots = MathFloor(lots / step + 1e-9) * step;
   if(lots < vmin)
     {
      PrintFormat("VwapScalper EA: lot %.4f below broker minimum %.2f - trade skipped", lots, vmin);
      return(0.0);
     }
   lots = MathMin(lots, vmax);
   int digits = (int)MathMax(0.0, MathCeil(-MathLog10(step)));
   return(NormalizeDouble(lots, digits));
  }

//+------------------------------------------------------------------+
bool IsOurs()
  {
   return(PositionGetString(POSITION_SYMBOL) == _Symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic);
  }

//+------------------------------------------------------------------+
int CountPositions()
  {
   int count = 0;
   for(int k = PositionsTotal() - 1; k >= 0; k--)
      if(PositionGetTicket(k) != 0 && IsOurs())
         count++;
   return(count);
  }

//+------------------------------------------------------------------+
void CloseTicket(const ulong ticket, const string why)
  {
   if(trade.PositionClose(ticket))
      PrintFormat("VwapScalper EA: closed #%I64u (%s)", ticket, why);
   else
      PrintFormat("VwapScalper EA: failed to close #%I64u (%s), retcode %u",
                  ticket, why, trade.ResultRetcode());
  }

//+------------------------------------------------------------------+
//| Close positions whose last closed bar is on the wrong VWAP side  |
//+------------------------------------------------------------------+
void VwapCrossExit(const int i)
  {
   for(int k = PositionsTotal() - 1; k >= 0; k--)
     {
      ulong ticket = PositionGetTicket(k);
      if(ticket == 0 || !IsOurs()) continue;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY  && W_close[i] < W_vwap[i]) CloseTicket(ticket, "closed below VWAP");
      if(type == POSITION_TYPE_SELL && W_close[i] > W_vwap[i]) CloseTicket(ticket, "closed above VWAP");
     }
  }

//+------------------------------------------------------------------+
//| Breakeven, time stop, session / VWAP-reset exits (every tick)    |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   datetime now     = TimeCurrent();
   double   minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   for(int k = PositionsTotal() - 1; k >= 0; k--)
     {
      ulong ticket = PositionGetTicket(k);
      if(ticket == 0 || !IsOurs()) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      //--- exits
      if(InpMaxBarsInTrade > 0 && now - opened >= (long)InpMaxBarsInTrade * PeriodSeconds(_Period))
        { CloseTicket(ticket, "time stop"); continue; }
      if(InpCloseOutsideSession && !VS_InSession(now))
        { CloseTicket(ticket, "session ended"); continue; }
      if(InpCloseAtVwapReset && VS_SessionId(now) != VS_SessionId(opened))
        { CloseTicket(ticket, "VWAP reset"); continue; }

      //--- breakeven at X R (risk = distance to original SL)
      if(InpBeAtR <= 0.0 || sl == 0.0)
         continue;
      if(type == POSITION_TYPE_BUY && sl < open)
        {
         double risk = open - sl;
         double be   = NormalizeDouble(open + InpBeLockPoints * _Point, _Digits);
         if(tick.bid - open >= InpBeAtR * risk && tick.bid - be >= minDist)
            if(!trade.PositionModify(ticket, be, tp))
               PrintFormat("VwapScalper EA: BE modify #%I64u failed, retcode %u", ticket, trade.ResultRetcode());
        }
      else if(type == POSITION_TYPE_SELL && sl > open)
        {
         double risk = sl - open;
         double be   = NormalizeDouble(open - InpBeLockPoints * _Point, _Digits);
         if(open - tick.ask >= InpBeAtR * risk && be - tick.ask >= minDist)
            if(!trade.PositionModify(ticket, be, tp))
               PrintFormat("VwapScalper EA: BE modify #%I64u failed, retcode %u", ticket, trade.ResultRetcode());
        }
     }
  }

//+------------------------------------------------------------------+
//| Max trades per day and daily loss stop (this EA only)            |
//+------------------------------------------------------------------+
bool DailyLimitsOk()
  {
   if(InpMaxTradesPerDay <= 0 && InpMaxDailyLossPct <= 0.0)
      return(true);

   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(!HistorySelect(dayStart, TimeCurrent() + 60))
      return(true);

   int    trades = 0;
   double pnl    = 0.0;
   for(int k = HistoryDealsTotal() - 1; k >= 0; k--)
     {
      ulong deal = HistoryDealGetTicket(k);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         trades++;
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT) +
             HistoryDealGetDouble(deal, DEAL_SWAP) +
             HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }

   if(InpMaxTradesPerDay > 0 && trades >= InpMaxTradesPerDay)
     {
      Print("VwapScalper EA: max trades per day reached");
      return(false);
     }
   if(InpMaxDailyLossPct > 0.0 &&
      pnl <= -AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxDailyLossPct / 100.0)
     {
      Print("VwapScalper EA: daily loss limit reached, no more trades today");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool SpreadOk()
  {
   if(InpMaxSpreadPoints <= 0)
      return(true);
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
     {
      PrintFormat("VwapScalper EA: spread %d > max %d, signal skipped", (int)spread, InpMaxSpreadPoints);
      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
