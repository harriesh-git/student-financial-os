//+------------------------------------------------------------------+
//|                                             VwapScalperCore.mqh |
//|  Shared engine for the VWAP + EMA Scalper EA and indicator.      |
//|  Both programs call VS_VwapStep() and VS_Evaluate(), so the bot  |
//|  trades exactly the arrows the indicator draws.                  |
//|                                                                  |
//|  Strategy: "VWAP trend + EMA pullback"                           |
//|   BUY when ALL are true on a closed bar:                         |
//|    1. Bias   : close above session VWAP and VWAP sloping up      |
//|    2. Trend  : fast EMA above slow EMA                           |
//|    3. Trigger: bar pulled back into the fast EMA and closed back |
//|                above it as a bullish candle (first such bar)     |
//|    4. Not chasing: close is within N x ATR of VWAP               |
//|    5. Inside the trading session, after the first bars of the    |
//|       session (VWAP is unstable right after its reset)           |
//|   SELL is the exact mirror image.                                |
//|   SL beyond the signal candle (clamped by ATR), TP = RR x risk.  |
//+------------------------------------------------------------------+
#ifndef VWAP_SCALPER_CORE_MQH
#define VWAP_SCALPER_CORE_MQH

#define VS_NONE  0
#define VS_BUY   1
#define VS_SELL -1

input group "=== Strategy (shared by EA & Indicator) ==="
input int                 InpFastEma        = 9;           // Fast EMA period
input int                 InpSlowEma        = 21;          // Slow EMA period
input int                 InpAtrPeriod      = 14;          // ATR period
input ENUM_APPLIED_VOLUME InpVolumeType     = VOLUME_TICK; // VWAP volume (tick for forex/CFD, real for futures/stocks)
input int                 InpResetHour      = 0;           // VWAP session reset hour (server time)
input int                 InpSlopeBars      = 5;           // VWAP slope lookback (bars)
input double              InpMinSlopeAtr    = 0.05;        // Min VWAP slope over lookback (x ATR), filters flat/choppy VWAP
input double              InpTouchAtr       = 0.10;        // Pullback counts if low/high comes within this of fast EMA (x ATR)
input double              InpMaxExtAtr      = 2.0;         // Max distance of close from VWAP (x ATR), avoids chasing
input int                 InpMinSessionBars = 6;           // Ignore first N bars after VWAP reset
input int                 InpSessionStart   = 10;          // Signal session start hour (server time)
input int                 InpSessionEnd     = 22;          // Signal session end hour (server time, exclusive)

input group "=== Stops & targets (shared) ==="
input double InpSlBufferAtr = 0.20;  // SL buffer beyond signal candle (x ATR)
input double InpMinSlAtr    = 0.50;  // Min SL distance (x ATR)
input double InpMaxSlAtr    = 2.00;  // Max SL distance (x ATR)
input double InpRewardRisk  = 1.5;   // Take profit = risk x this

int VS_hFast = INVALID_HANDLE;
int VS_hSlow = INVALID_HANDLE;
int VS_hAtr  = INVALID_HANDLE;

//+------------------------------------------------------------------+
bool VS_ValidateInputs()
  {
   if(InpFastEma < 1 || InpSlowEma < 1 || InpAtrPeriod < 1 || InpSlopeBars < 1)
     { Print("VwapScalper: periods must be >= 1"); return(false); }
   if(InpFastEma >= InpSlowEma)
     { Print("VwapScalper: fast EMA must be smaller than slow EMA"); return(false); }
   if(InpResetHour < 0 || InpResetHour > 23 || InpSessionStart < 0 || InpSessionStart > 23 ||
      InpSessionEnd < 0 || InpSessionEnd > 23)
     { Print("VwapScalper: hours must be between 0 and 23"); return(false); }
   if(InpMinSlAtr <= 0.0 || InpMaxSlAtr < InpMinSlAtr || InpRewardRisk <= 0.0)
     { Print("VwapScalper: check SL/TP settings (min SL > 0, max SL >= min SL, RR > 0)"); return(false); }
   return(true);
  }

//+------------------------------------------------------------------+
bool VS_Init(const string symbol, const ENUM_TIMEFRAMES tf)
  {
   if(!VS_ValidateInputs())
      return(false);
   VS_hFast = iMA(symbol, tf, InpFastEma, 0, MODE_EMA, PRICE_CLOSE);
   VS_hSlow = iMA(symbol, tf, InpSlowEma, 0, MODE_EMA, PRICE_CLOSE);
   VS_hAtr  = iATR(symbol, tf, InpAtrPeriod);
   if(VS_hFast == INVALID_HANDLE || VS_hSlow == INVALID_HANDLE || VS_hAtr == INVALID_HANDLE)
     {
      PrintFormat("VwapScalper: failed to create indicator handles, error %d", GetLastError());
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void VS_Deinit()
  {
   if(VS_hFast != INVALID_HANDLE) { IndicatorRelease(VS_hFast); VS_hFast = INVALID_HANDLE; }
   if(VS_hSlow != INVALID_HANDLE) { IndicatorRelease(VS_hSlow); VS_hSlow = INVALID_HANDLE; }
   if(VS_hAtr  != INVALID_HANDLE) { IndicatorRelease(VS_hAtr);  VS_hAtr  = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
bool VS_HandlesReady(const int bars)
  {
   return(BarsCalculated(VS_hFast) >= bars &&
          BarsCalculated(VS_hSlow) >= bars &&
          BarsCalculated(VS_hAtr)  >= bars);
  }

//+------------------------------------------------------------------+
int VS_MinBars()
  {
   return(MathMax(MathMax(InpSlowEma, InpAtrPeriod), InpSlopeBars) + 2);
  }

//+------------------------------------------------------------------+
//| Session day id: bars with the same id share one VWAP             |
//+------------------------------------------------------------------+
long VS_SessionId(const datetime t)
  {
   return((long)(t - InpResetHour * 3600) / 86400);
  }

//+------------------------------------------------------------------+
bool VS_InSession(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   if(InpSessionStart == InpSessionEnd)
      return(true);                                   // 24h
   if(InpSessionStart < InpSessionEnd)
      return(s.hour >= InpSessionStart && s.hour < InpSessionEnd);
   return(s.hour >= InpSessionStart || s.hour < InpSessionEnd);  // crosses midnight
  }

//+------------------------------------------------------------------+
//| Pick volume per input; fall back to tick volume, then 1          |
//+------------------------------------------------------------------+
double VS_Volume(const long tickVol, const long realVol)
  {
   double v = (InpVolumeType == VOLUME_REAL && realVol > 0) ? (double)realVol : (double)tickVol;
   return(v > 0.0 ? v : 1.0);
  }

//+------------------------------------------------------------------+
//| One step of session-anchored VWAP (+ standard deviation).        |
//| Arrays are indexed oldest -> newest. Fills bar i from bar i-1.   |
//+------------------------------------------------------------------+
void VS_VwapStep(const int i, const datetime &time[],
                 const double &high[], const double &low[], const double &close[],
                 const double vol,
                 double &cumPV[], double &cumV[], double &cumP2V[],
                 double &sessBar[], double &vwap[], double &sd[])
  {
   double tp = (high[i] + low[i] + close[i]) / 3.0;
   bool newSession = (i == 0 || VS_SessionId(time[i]) != VS_SessionId(time[i - 1]));
   if(newSession)
     {
      cumPV[i]   = tp * vol;
      cumV[i]    = vol;
      cumP2V[i]  = tp * tp * vol;
      sessBar[i] = 0;
     }
   else
     {
      cumPV[i]   = cumPV[i - 1]  + tp * vol;
      cumV[i]    = cumV[i - 1]   + vol;
      cumP2V[i]  = cumP2V[i - 1] + tp * tp * vol;
      sessBar[i] = sessBar[i - 1] + 1;
     }
   vwap[i] = cumPV[i] / cumV[i];
   double var = cumP2V[i] / cumV[i] - vwap[i] * vwap[i];
   sd[i] = (var > 0.0) ? MathSqrt(var) : 0.0;
  }

//+------------------------------------------------------------------+
//| Pullback-rejection candle helpers                                |
//+------------------------------------------------------------------+
bool VS_LongTrigger(const int i, const double &open[], const double &low[],
                    const double &close[], const double &emaF[], const double atr)
  {
   return(low[i] <= emaF[i] + InpTouchAtr * atr && close[i] > emaF[i] && close[i] > open[i]);
  }

bool VS_ShortTrigger(const int i, const double &open[], const double &high[],
                     const double &close[], const double &emaF[], const double atr)
  {
   return(high[i] >= emaF[i] - InpTouchAtr * atr && close[i] < emaF[i] && close[i] < open[i]);
  }

//+------------------------------------------------------------------+
//| THE signal rule - single source of truth for EA and indicator.   |
//| Arrays are indexed oldest -> newest, i = the closed signal bar.  |
//+------------------------------------------------------------------+
int VS_Evaluate(const int i, const datetime &time[],
                const double &open[], const double &high[],
                const double &low[],  const double &close[],
                const double &emaF[], const double &emaS[], const double &atr[],
                const double &vwap[], const double &sessBar[])
  {
   if(i < InpSlopeBars + 1)
      return(VS_NONE);
   if(sessBar[i] < InpMinSessionBars || sessBar[i] < InpSlopeBars)
      return(VS_NONE);
   if(!VS_InSession(time[i]))
      return(VS_NONE);

   double a = atr[i];
   if(a <= 0.0)
      return(VS_NONE);

   double slope = vwap[i] - vwap[i - InpSlopeBars];

   //--- long
   if(close[i] > vwap[i] && slope > InpMinSlopeAtr * a && emaF[i] > emaS[i] &&
      close[i] - vwap[i] <= InpMaxExtAtr * a &&
      VS_LongTrigger(i, open, low, close, emaF, a) &&
      !VS_LongTrigger(i - 1, open, low, close, emaF, atr[i - 1]))
      return(VS_BUY);

   //--- short
   if(close[i] < vwap[i] && slope < -InpMinSlopeAtr * a && emaF[i] < emaS[i] &&
      vwap[i] - close[i] <= InpMaxExtAtr * a &&
      VS_ShortTrigger(i, open, high, close, emaF, a) &&
      !VS_ShortTrigger(i - 1, open, high, close, emaF, atr[i - 1]))
      return(VS_SELL);

   return(VS_NONE);
  }

//+------------------------------------------------------------------+
//| SL/TP for a signal. `entry` is the actual (or assumed) fill.     |
//| SL sits beyond the signal candle, clamped to [min,max] x ATR.    |
//+------------------------------------------------------------------+
bool VS_Levels(const int signal, const double entry,
               const double sigHigh, const double sigLow, const double atr,
               double &sl, double &tp)
  {
   if(signal == VS_NONE || atr <= 0.0)
      return(false);

   double dist;
   if(signal == VS_BUY)
      dist = entry - (sigLow - InpSlBufferAtr * atr);
   else
      dist = (sigHigh + InpSlBufferAtr * atr) - entry;

   dist = MathMax(dist, InpMinSlAtr * atr);
   dist = MathMin(dist, InpMaxSlAtr * atr);

   if(signal == VS_BUY)
     {
      sl = entry - dist;
      tp = entry + dist * InpRewardRisk;
     }
   else
     {
      sl = entry + dist;
      tp = entry - dist * InpRewardRisk;
     }
   return(true);
  }

#endif // VWAP_SCALPER_CORE_MQH
//+------------------------------------------------------------------+
