//+------------------------------------------------------------------+
//|                                        TrendPulse_Indicator.mq5 |
//|  Visual version of the TrendPulse EA. Draws the MAs and a        |
//|  BUY/SELL arrow on every bar where the EA would open a trade.    |
//|  Signal logic lives in Include/TrendPulse/TrendPulseCore.mqh     |
//+------------------------------------------------------------------+
#property copyright "TrendPulse"
#property version   "1.00"
#property description "EMA crossover + trend + RSI filter signals (same logic as TrendPulse EA)"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   5

//--- plot 0: fast MA
#property indicator_label1  "Fast MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot 1: slow MA
#property indicator_label2  "Slow MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
//--- plot 2: trend MA
#property indicator_label3  "Trend MA"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
//--- plot 3: buy arrows
#property indicator_label4  "Buy"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  3
//--- plot 4: sell arrows
#property indicator_label5  "Sell"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  3

#include <TrendPulse/TrendPulseCore.mqh>

input group "=== Indicator display & alerts ==="
input bool   InpShowTrendMa    = true;   // Show trend MA line
input double InpArrowOffsetAtr = 0.3;    // Arrow distance from candle (x ATR)
input bool   InpShowLiveBar    = false;  // Show signal on forming bar (repaints)
input bool   InpAlertPopup     = true;   // Popup alert on new signal
input bool   InpAlertSound     = false;  // Sound alert on new signal
input bool   InpAlertPush      = false;  // Push notification to phone
input bool   InpAlertEmail     = false;  // Email alert

//--- buffers
double FastBuf[];
double SlowBuf[];
double TrendBuf[];
double BuyBuf[];
double SellBuf[];
double RsiBuf[];
double AtrBuf[];

datetime g_lastAlertBar = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!TP_Init(_Symbol, _Period))
      return(INIT_FAILED);

   SetIndexBuffer(0, FastBuf,  INDICATOR_DATA);
   SetIndexBuffer(1, SlowBuf,  INDICATOR_DATA);
   SetIndexBuffer(2, TrendBuf, INDICATOR_DATA);
   SetIndexBuffer(3, BuyBuf,   INDICATOR_DATA);
   SetIndexBuffer(4, SellBuf,  INDICATOR_DATA);
   SetIndexBuffer(5, RsiBuf,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, AtrBuf,   INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(3, PLOT_ARROW, 233);   // up arrow
   PlotIndexSetInteger(4, PLOT_ARROW, 234);   // down arrow
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(!InpShowTrendMa || !InpUseTrendFilter)
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpFastPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpSlowPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpTrendPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("TrendPulse(%d,%d,%d)", InpFastPeriod, InpSlowPeriod, InpTrendPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   TP_Deinit();
  }

//+------------------------------------------------------------------+
void SendSignalAlert(const string side, const datetime barTime,
                     const double price, const double atr)
  {
   double sl, tp;
   if(side == "BUY")
     {
      sl = price - atr * InpSlAtrMult;
      tp = price + atr * InpTpAtrMult;
     }
   else
     {
      sl = price + atr * InpSlAtrMult;
      tp = price - atr * InpTpAtrMult;
     }

   string msg = StringFormat("TrendPulse %s %s %s @ %s | SL %s | TP %s",
                             side, _Symbol, EnumToString(_Period),
                             DoubleToString(price, _Digits),
                             DoubleToString(sl, _Digits),
                             DoubleToString(tp, _Digits));
   if(InpAlertPopup) Alert(msg);
   if(InpAlertSound) PlaySound("alert.wav");
   if(InpAlertPush)  SendNotification(msg);
   if(InpAlertEmail) SendMail("TrendPulse " + side + " " + _Symbol, msg);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int minBars = TP_MinBars();
   if(rates_total < minBars)
      return(0);
   if(!TP_HandlesReady(rates_total))
      return(0);

   //--- how much data to (re)copy from the source indicators
   int to_copy;
   if(prev_calculated <= 0 || prev_calculated > rates_total)
      to_copy = rates_total;
   else
      to_copy = rates_total - prev_calculated + 1;

   if(CopyBuffer(TP_hFast,  0, 0, to_copy, FastBuf)  <= 0) return(0);
   if(CopyBuffer(TP_hSlow,  0, 0, to_copy, SlowBuf)  <= 0) return(0);
   if(CopyBuffer(TP_hTrend, 0, 0, to_copy, TrendBuf) <= 0) return(0);
   if(CopyBuffer(TP_hRsi,   0, 0, to_copy, RsiBuf)   <= 0) return(0);
   if(CopyBuffer(TP_hAtr,   0, 0, to_copy, AtrBuf)   <= 0) return(0);

   int start;
   if(prev_calculated <= 0 || prev_calculated > rates_total)
     {
      ArrayInitialize(BuyBuf,  EMPTY_VALUE);
      ArrayInitialize(SellBuf, EMPTY_VALUE);
      start = minBars;
     }
   else
      start = MathMax(prev_calculated - 1, minBars);

   //--- same rule the EA uses, evaluated bar by bar
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      BuyBuf[i]  = EMPTY_VALUE;
      SellBuf[i] = EMPTY_VALUE;

      if(i == rates_total - 1 && !InpShowLiveBar)
         continue;   // EA only acts on closed bars

      int sig = TP_Evaluate(FastBuf[i], FastBuf[i - 1],
                            SlowBuf[i], SlowBuf[i - 1],
                            close[i], TrendBuf[i], RsiBuf[i]);

      double offset = AtrBuf[i] * InpArrowOffsetAtr;
      if(sig == TP_BUY)
         BuyBuf[i] = low[i] - offset;
      else if(sig == TP_SELL)
         SellBuf[i] = high[i] + offset;
     }

   //--- alert once per closed signal bar (skip history on first load)
   int last = rates_total - 2;
   if(last >= 0 && time[last] != g_lastAlertBar)
     {
      if(prev_calculated > 0)
        {
         if(BuyBuf[last] != EMPTY_VALUE)
            SendSignalAlert("BUY", time[last], close[last], AtrBuf[last]);
         else if(SellBuf[last] != EMPTY_VALUE)
            SendSignalAlert("SELL", time[last], close[last], AtrBuf[last]);
        }
      g_lastAlertBar = time[last];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
