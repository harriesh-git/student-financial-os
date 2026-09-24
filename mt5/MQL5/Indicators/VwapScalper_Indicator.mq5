//+------------------------------------------------------------------+
//|                                       VwapScalper_Indicator.mq5 |
//|  Visual version of the VWAP + EMA Scalper EA.                    |
//|  Draws session VWAP with 1/2 SD bands, the EMAs and BUY/SELL     |
//|  arrows exactly where the EA would enter.                        |
//|  Logic lives in Include/VwapScalper/VwapScalperCore.mqh          |
//+------------------------------------------------------------------+
#property copyright "VwapScalper"
#property version   "1.00"
#property description "Session VWAP + EMA pullback scalping signals (same logic as VwapScalper EA)"
#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   9

#property indicator_label1  "Fast EMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1

#property indicator_label2  "Slow EMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1

#property indicator_label3  "VWAP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_width3  2

#property indicator_label4  "VWAP +1SD"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGray
#property indicator_style4  STYLE_DOT

#property indicator_label5  "VWAP -1SD"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGray
#property indicator_style5  STYLE_DOT

#property indicator_label6  "VWAP +2SD"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrDimGray
#property indicator_style6  STYLE_DASH

#property indicator_label7  "VWAP -2SD"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrDimGray
#property indicator_style7  STYLE_DASH

#property indicator_label8  "Buy"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrLime
#property indicator_width8  3

#property indicator_label9  "Sell"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrRed
#property indicator_width9  3

#include <VwapScalper/VwapScalperCore.mqh>

input group "=== Indicator display & alerts ==="
input bool   InpShowBands      = true;   // Show VWAP 1/2 SD bands
input double InpArrowOffsetAtr = 0.3;    // Arrow distance from candle (x ATR)
input bool   InpAlertPopup     = true;   // Popup alert on new signal
input bool   InpAlertSound     = false;  // Sound alert on new signal
input bool   InpAlertPush      = false;  // Push notification to phone
input bool   InpAlertEmail     = false;  // Email alert

double FastBuf[], SlowBuf[], VwapBuf[], Up1Buf[], Dn1Buf[], Up2Buf[], Dn2Buf[];
double BuyBuf[], SellBuf[];
double AtrBuf[], CumPV[], CumV[], CumP2V[], SessBar[];
double SdWork[];   // VWAP standard deviation scratch array

datetime g_lastAlertBar = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!VS_Init(_Symbol, _Period))
      return(INIT_FAILED);

   SetIndexBuffer(0,  FastBuf, INDICATOR_DATA);
   SetIndexBuffer(1,  SlowBuf, INDICATOR_DATA);
   SetIndexBuffer(2,  VwapBuf, INDICATOR_DATA);
   SetIndexBuffer(3,  Up1Buf,  INDICATOR_DATA);
   SetIndexBuffer(4,  Dn1Buf,  INDICATOR_DATA);
   SetIndexBuffer(5,  Up2Buf,  INDICATOR_DATA);
   SetIndexBuffer(6,  Dn2Buf,  INDICATOR_DATA);
   SetIndexBuffer(7,  BuyBuf,  INDICATOR_DATA);
   SetIndexBuffer(8,  SellBuf, INDICATOR_DATA);
   SetIndexBuffer(9,  AtrBuf,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, CumPV,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, CumV,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, CumP2V,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, SessBar, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(7, PLOT_ARROW, 233);
   PlotIndexSetInteger(8, PLOT_ARROW, 234);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(!InpShowBands)
      for(int p = 3; p <= 6; p++)
         PlotIndexSetInteger(p, PLOT_DRAW_TYPE, DRAW_NONE);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpFastEma);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpSlowEma);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("VwapScalper(%d,%d)", InpFastEma, InpSlowEma));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   VS_Deinit();
  }

//+------------------------------------------------------------------+
void SendSignalAlert(const int sig, const double entry, const double sl, const double tp)
  {
   string side = (sig == VS_BUY) ? "BUY" : "SELL";
   string msg = StringFormat("VwapScalper %s %s %s @ %s | SL %s | TP %s",
                             side, _Symbol, EnumToString(_Period),
                             DoubleToString(entry, _Digits),
                             DoubleToString(sl, _Digits),
                             DoubleToString(tp, _Digits));
   if(InpAlertPopup) Alert(msg);
   if(InpAlertSound) PlaySound("alert.wav");
   if(InpAlertPush)  SendNotification(msg);
   if(InpAlertEmail) SendMail("VwapScalper " + side + " " + _Symbol, msg);
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
   int minBars = VS_MinBars();
   if(rates_total < minBars)
      return(0);
   if(!VS_HandlesReady(rates_total))
      return(0);

   bool full = (prev_calculated <= 0 || prev_calculated > rates_total);
   int to_copy = full ? rates_total : rates_total - prev_calculated + 1;

   if(CopyBuffer(VS_hFast, 0, 0, to_copy, FastBuf) <= 0) return(0);
   if(CopyBuffer(VS_hSlow, 0, 0, to_copy, SlowBuf) <= 0) return(0);
   if(CopyBuffer(VS_hAtr,  0, 0, to_copy, AtrBuf)  <= 0) return(0);

   int start = full ? 0 : prev_calculated - 1;
   if(full)
     {
      ArrayInitialize(BuyBuf,  EMPTY_VALUE);
      ArrayInitialize(SellBuf, EMPTY_VALUE);
     }

   ArrayResize(SdWork, rates_total, 1000);

   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      //--- session VWAP + bands (shared step function)
      VS_VwapStep(i, time, high, low, close, VS_Volume(tick_volume[i], volume[i]),
                  CumPV, CumV, CumP2V, SessBar, VwapBuf, SdWork);
      Up1Buf[i] = VwapBuf[i] + SdWork[i];
      Dn1Buf[i] = VwapBuf[i] - SdWork[i];
      Up2Buf[i] = VwapBuf[i] + 2.0 * SdWork[i];
      Dn2Buf[i] = VwapBuf[i] - 2.0 * SdWork[i];

      //--- signal (closed bars only, same as the EA)
      BuyBuf[i]  = EMPTY_VALUE;
      SellBuf[i] = EMPTY_VALUE;
      if(i < minBars || i == rates_total - 1)
         continue;

      int sig = VS_Evaluate(i, time, open, high, low, close,
                            FastBuf, SlowBuf, AtrBuf, VwapBuf, SessBar);
      double offset = AtrBuf[i] * InpArrowOffsetAtr;
      if(sig == VS_BUY)
         BuyBuf[i] = low[i] - offset;
      else if(sig == VS_SELL)
         SellBuf[i] = high[i] + offset;
     }

   //--- alert once per new closed signal bar (not on history load)
   int last = rates_total - 2;
   if(last >= minBars && time[last] != g_lastAlertBar)
     {
      if(!full)
        {
         int sig = VS_NONE;
         if(BuyBuf[last]  != EMPTY_VALUE) sig = VS_BUY;
         if(SellBuf[last] != EMPTY_VALUE) sig = VS_SELL;
         double sl, tp;
         if(sig != VS_NONE &&
            VS_Levels(sig, close[last], high[last], low[last], AtrBuf[last], sl, tp))
            SendSignalAlert(sig, close[last], sl, tp);
        }
      g_lastAlertBar = time[last];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
