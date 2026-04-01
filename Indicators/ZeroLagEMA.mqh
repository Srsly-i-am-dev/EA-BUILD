//+------------------------------------------------------------------+
//| ZeroLagEMA.mqh                                                    |
//| Zero-Lag EMA with volatility bands for trend detection            |
//| Formula: ZLEMA = EMA(src + (src - src[lag]), length)              |
//| Ported from AlgoAlpha PineScript implementation                   |
//+------------------------------------------------------------------+
#ifndef ZERO_LAG_EMA_MQH
#define ZERO_LAG_EMA_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CZeroLagEMA                                                       |
//+------------------------------------------------------------------+
class CZeroLagEMA
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_length;
   double            m_band_mult;
   int               m_atr_handle;

   //--- State
   double            m_zlema;         // Current ZLEMA value
   double            m_volatility;    // Current volatility band width
   int               m_trend;         // DIR_BUY or DIR_SELL
   bool              m_initialized;

   //--- EMA smoothing
   double            m_alpha;         // EMA smoothing factor: 2/(length+1)

   double ReadATR(int shift)
   {
      double buf[];
      if(CopyBuffer(m_atr_handle, 0, shift, 1, buf) < 1) return 0;
      return buf[0];
   }

public:
   CZeroLagEMA() : m_atr_handle(INVALID_HANDLE), m_length(70),
                   m_band_mult(1.2), m_zlema(0), m_volatility(0),
                   m_trend(DIR_NONE), m_initialized(false), m_alpha(0) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int length, double band_mult)
   {
      m_symbol    = symbol;
      m_tf        = tf;
      m_length    = length;
      m_band_mult = band_mult;
      m_alpha     = 2.0 / (length + 1.0);
      m_initialized = false;

      m_atr_handle = iATR(symbol, tf, length);
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("[ZLEMA] Failed to create ATR(", length, ") handle");
         return false;
      }
      return true;
   }

   void Deinit()
   {
      if(m_atr_handle != INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);
      m_atr_handle = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Update ZLEMA on new bar                                           |
   //+------------------------------------------------------------------+
   void Update(int shift = 1)
   {
      int lag = (m_length - 1) / 2;

      double close_curr = iClose(m_symbol, m_tf, shift);
      double close_lag  = iClose(m_symbol, m_tf, shift + lag);
      if(close_curr == 0 || close_lag == 0) return;

      //--- Zero-lag adjusted source: src + (src - src[lag])
      double zl_src = close_curr + (close_curr - close_lag);

      //--- EMA smoothing
      if(!m_initialized)
      {
         m_zlema = zl_src;
         m_initialized = true;
      }
      else
      {
         m_zlema = m_alpha * zl_src + (1.0 - m_alpha) * m_zlema;
      }

      //--- Volatility bands: highest ATR over length*3 bars * multiplier
      double max_atr = 0;
      int lookback = m_length * 3;
      for(int i = shift; i < shift + lookback; i++)
      {
         double a = ReadATR(i);
         if(a > max_atr) max_atr = a;
      }
      m_volatility = max_atr * m_band_mult;

      //--- Trend detection via band crossover
      if(close_curr > m_zlema + m_volatility)
         m_trend = DIR_BUY;
      else if(close_curr < m_zlema - m_volatility)
         m_trend = DIR_SELL;
      // else: keep previous trend (no flip in neutral zone)
   }

   //+------------------------------------------------------------------+
   //| Bootstrap warmup                                                   |
   //+------------------------------------------------------------------+
   void Warmup(int bars = 300)
   {
      m_initialized = false;
      m_trend = DIR_NONE;
      for(int i = bars; i >= 1; i--)
         Update(i);
   }

   //--- Accessors
   int    GetDirection()  { return m_trend; }
   double GetValue()      { return m_zlema; }
   double GetVolatility() { return m_volatility; }
   double GetUpperBand()  { return m_zlema + m_volatility; }
   double GetLowerBand()  { return m_zlema - m_volatility; }
};

#endif
