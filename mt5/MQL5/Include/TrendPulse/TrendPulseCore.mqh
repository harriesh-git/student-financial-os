//+------------------------------------------------------------------+
//|                                              TrendPulseCore.mqh |
//|  Shared signal engine used by BOTH the TrendPulse EA and the     |
//|  TrendPulse indicator, so the bot trades exactly what the        |
//|  indicator draws.                                                |
//|                                                                  |
//|  Strategy:                                                       |
//|   BUY  : fast MA crosses ABOVE slow MA                           |
//|          + (optional) close above trend MA                       |
//|          + (optional) RSI above buy level                        |
//|   SELL : fast MA crosses BELOW slow MA                           |
//|          + (optional) close below trend MA                       |
//|          + (optional) RSI below sell level                       |
//|   SL/TP: multiples of ATR measured on the signal bar             |
//+------------------------------------------------------------------+
#ifndef TRENDPULSE_CORE_MQH
#define TRENDPULSE_CORE_MQH

//--- signal codes
#define TP_NONE  0
#define TP_BUY   1
#define TP_SELL -1

//--- strategy inputs (shared, so EA and indicator use identical settings)
input group "=== Strategy (shared by EA & Indicator) ==="
input int                InpFastPeriod     = 9;            // Fast MA period
input int                InpSlowPeriod     = 21;           // Slow MA period
input ENUM_MA_METHOD     InpMaMethod       = MODE_EMA;     // MA method
input ENUM_APPLIED_PRICE InpMaPrice        = PRICE_CLOSE;  // MA applied price
input bool               InpUseTrendFilter = true;         // Use trend MA filter
input int                InpTrendPeriod    = 200;          // Trend MA period
input bool               InpUseRsiFilter   = true;         // Use RSI filter
input int                InpRsiPeriod      = 14;           // RSI period
input double             InpRsiBuyLevel    = 50.0;         // RSI must be above this to buy
input double             InpRsiSellLevel   = 50.0;         // RSI must be below this to sell
input int                InpAtrPeriod      = 14;           // ATR period
input double             InpSlAtrMult      = 1.5;          // Stop loss = ATR x this
input double             InpTpAtrMult      = 3.0;          // Take profit = ATR x this

//--- indicator handles
int             TP_hFast  = INVALID_HANDLE;
int             TP_hSlow  = INVALID_HANDLE;
int             TP_hTrend = INVALID_HANDLE;
int             TP_hRsi   = INVALID_HANDLE;
int             TP_hAtr   = INVALID_HANDLE;
string          TP_Symbol = "";
ENUM_TIMEFRAMES TP_Tf     = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Validate inputs                                                  |
//+------------------------------------------------------------------+
bool TP_ValidateInputs()
  {
   if(InpFastPeriod < 1 || InpSlowPeriod < 1 || InpTrendPeriod < 1 ||
      InpRsiPeriod < 1 || InpAtrPeriod < 1)
     {
      Print("TrendPulse: all periods must be >= 1");
      return(false);
     }
   if(InpFastPeriod >= InpSlowPeriod)
     {
      Print("TrendPulse: fast MA period must be smaller than slow MA period");
      return(false);
     }
   if(InpSlAtrMult <= 0.0 || InpTpAtrMult <= 0.0)
     {
      Print("TrendPulse: SL/TP ATR multipliers must be > 0");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Create all indicator handles                                     |
//+------------------------------------------------------------------+
bool TP_Init(const string symbol, const ENUM_TIMEFRAMES tf)
  {
   if(!TP_ValidateInputs())
      return(false);

   TP_Symbol = symbol;
   TP_Tf     = tf;

   TP_hFast  = iMA(symbol, tf, InpFastPeriod,  0, InpMaMethod, InpMaPrice);
   TP_hSlow  = iMA(symbol, tf, InpSlowPeriod,  0, InpMaMethod, InpMaPrice);
   TP_hTrend = iMA(symbol, tf, InpTrendPeriod, 0, InpMaMethod, InpMaPrice);
   TP_hRsi   = iRSI(symbol, tf, InpRsiPeriod, InpMaPrice);
   TP_hAtr   = iATR(symbol, tf, InpAtrPeriod);

   if(TP_hFast == INVALID_HANDLE || TP_hSlow == INVALID_HANDLE ||
      TP_hTrend == INVALID_HANDLE || TP_hRsi == INVALID_HANDLE ||
      TP_hAtr == INVALID_HANDLE)
     {
      PrintFormat("TrendPulse: failed to create indicator handles, error %d", GetLastError());
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Release all indicator handles                                    |
//+------------------------------------------------------------------+
void TP_Deinit()
  {
   if(TP_hFast  != INVALID_HANDLE) { IndicatorRelease(TP_hFast);  TP_hFast  = INVALID_HANDLE; }
   if(TP_hSlow  != INVALID_HANDLE) { IndicatorRelease(TP_hSlow);  TP_hSlow  = INVALID_HANDLE; }
   if(TP_hTrend != INVALID_HANDLE) { IndicatorRelease(TP_hTrend); TP_hTrend = INVALID_HANDLE; }
   if(TP_hRsi   != INVALID_HANDLE) { IndicatorRelease(TP_hRsi);   TP_hRsi   = INVALID_HANDLE; }
   if(TP_hAtr   != INVALID_HANDLE) { IndicatorRelease(TP_hAtr);   TP_hAtr   = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
//| Minimum number of bars before signals are meaningful             |
//+------------------------------------------------------------------+
int TP_MinBars()
  {
   int n = MathMax(InpSlowPeriod, InpFastPeriod);
   if(InpUseTrendFilter) n = MathMax(n, InpTrendPeriod);
   n = MathMax(n, InpRsiPeriod);
   n = MathMax(n, InpAtrPeriod);
   return(n + 2);
  }

//+------------------------------------------------------------------+
//| True when every handle has calculated at least `bars` bars       |
//+------------------------------------------------------------------+
bool TP_HandlesReady(const int bars)
  {
   return(BarsCalculated(TP_hFast)  >= bars &&
          BarsCalculated(TP_hSlow)  >= bars &&
          BarsCalculated(TP_hTrend) >= bars &&
          BarsCalculated(TP_hRsi)   >= bars &&
          BarsCalculated(TP_hAtr)   >= bars);
  }

//+------------------------------------------------------------------+
//| THE signal rule. Pure function - the single source of truth.     |
//| *Cur values are from the signal bar, *Prev from the bar before.  |
//+------------------------------------------------------------------+
int TP_Evaluate(const double fastCur, const double fastPrev,
                const double slowCur, const double slowPrev,
                const double close,   const double trend,
                const double rsi)
  {
   bool crossUp   = (fastPrev <= slowPrev && fastCur > slowCur);
   bool crossDown = (fastPrev >= slowPrev && fastCur < slowCur);

   if(crossUp)
     {
      if(InpUseTrendFilter && close <= trend)        return(TP_NONE);
      if(InpUseRsiFilter   && rsi   <= InpRsiBuyLevel) return(TP_NONE);
      return(TP_BUY);
     }
   if(crossDown)
     {
      if(InpUseTrendFilter && close >= trend)         return(TP_NONE);
      if(InpUseRsiFilter   && rsi   >= InpRsiSellLevel) return(TP_NONE);
      return(TP_SELL);
     }
   return(TP_NONE);
  }

//+------------------------------------------------------------------+
//| Read the signal on bar `shift` (1 = last closed bar).            |
//| Used by the EA. Returns false if data is not ready yet.          |
//+------------------------------------------------------------------+
bool TP_GetSignal(const int shift, int &signal, double &atr)
  {
   double f[], s[], t[], r[], a[];
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(s, true);
   ArraySetAsSeries(t, true);
   ArraySetAsSeries(r, true);
   ArraySetAsSeries(a, true);

   if(CopyBuffer(TP_hFast,  0, shift, 2, f) != 2) return(false);
   if(CopyBuffer(TP_hSlow,  0, shift, 2, s) != 2) return(false);
   if(CopyBuffer(TP_hTrend, 0, shift, 1, t) != 1) return(false);
   if(CopyBuffer(TP_hRsi,   0, shift, 1, r) != 1) return(false);
   if(CopyBuffer(TP_hAtr,   0, shift, 1, a) != 1) return(false);

   double close = iClose(TP_Symbol, TP_Tf, shift);
   if(close <= 0.0)
      return(false);

   signal = TP_Evaluate(f[0], f[1], s[0], s[1], close, t[0], r[0]);
   atr    = a[0];
   return(true);
  }

//+------------------------------------------------------------------+
//| Current ATR on bar `shift`                                       |
//+------------------------------------------------------------------+
bool TP_GetAtr(const int shift, double &atr)
  {
   double a[];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(TP_hAtr, 0, shift, 1, a) != 1)
      return(false);
   atr = a[0];
   return(true);
  }

#endif // TRENDPULSE_CORE_MQH
//+------------------------------------------------------------------+
