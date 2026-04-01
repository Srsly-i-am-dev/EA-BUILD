//+------------------------------------------------------------------+
//| TwoPoleFilter.mqh                                                 |
//| Two-Pole Smooth Oscillator for mean-reversion signals             |
//| Ported from BigBeluga PineScript implementation                   |
//| Signal: crossover/under of oscillator vs lagged value in OB/OS    |
//+------------------------------------------------------------------+
#ifndef TWO_POLE_FILTER_MQH
#define TWO_POLE_FILTER_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CTwoPoleFilter                                                     |
//+------------------------------------------------------------------+
class CTwoPoleFilter
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_length;        // Filter length (default 15)
   int               m_sma_period;    // SMA period for normalization (25)
   int               m_lag;           // Oscillator lag (4 bars)

   //--- Internal state
   double            m_smooth1;       // First pole
   double            m_smooth2;       // Second pole (output)
   double            m_alpha;         // Smoothing factor
   bool              m_initialized;

   //--- Oscillator history ring buffer (need lag+1 values)
   double            m_osc_buf[8];    // Ring buffer for oscillator values
   int               m_buf_idx;       // Current write position

   //--- Signal state
   int               m_signal;        // DIR_BUY, DIR_SELL, or DIR_NONE
   double            m_osc_value;     // Current oscillator value
   double            m_osc_lagged;    // Lagged oscillator value

   //--- SMA buffers for normalization
   double            m_close_buf[];   // Close prices for SMA
   double            m_diff_buf[];    // (close - SMA) buffer for second SMA
   int               m_bar_count;

public:
   CTwoPoleFilter() : m_length(15), m_sma_period(25), m_lag(4),
                      m_smooth1(0), m_smooth2(0), m_alpha(0),
                      m_initialized(false), m_buf_idx(0),
                      m_signal(DIR_NONE), m_osc_value(0), m_osc_lagged(0),
                      m_bar_count(0) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int length = 15)
   {
      m_symbol = symbol;
      m_tf     = tf;
      m_length = length;
      m_alpha  = 2.0 / (length + 1.0);
      m_initialized = false;
      m_bar_count   = 0;
      m_buf_idx     = 0;

      ArrayResize(m_close_buf, m_sma_period);
      ArrayResize(m_diff_buf, m_sma_period);
      ArrayInitialize(m_close_buf, 0);
      ArrayInitialize(m_diff_buf, 0);
      ArrayInitialize(m_osc_buf, 0);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Update on new bar                                                  |
   //+------------------------------------------------------------------+
   void Update(int shift = 1)
   {
      double close_val = iClose(m_symbol, m_tf, shift);
      if(close_val == 0) return;

      m_bar_count++;

      //--- Update close ring buffer for SMA(25)
      int cb_idx = (m_bar_count - 1) % m_sma_period;
      m_close_buf[cb_idx] = close_val;

      //--- Calculate SMA of close (25-period)
      int count = MathMin(m_bar_count, m_sma_period);
      double sma_close = 0;
      for(int i = 0; i < count; i++)
         sma_close += m_close_buf[i];
      sma_close /= count;

      //--- Difference: close - SMA(close, 25)
      double diff = close_val - sma_close;

      //--- Update diff ring buffer for SMA and StdDev
      int db_idx = (m_bar_count - 1) % m_sma_period;
      m_diff_buf[db_idx] = diff;

      //--- Calculate SMA(diff, 25) and StdDev(diff, 25)
      double sma_diff = 0;
      for(int i = 0; i < count; i++)
         sma_diff += m_diff_buf[i];
      sma_diff /= count;

      double var = 0;
      for(int i = 0; i < count; i++)
         var += (m_diff_buf[i] - sma_diff) * (m_diff_buf[i] - sma_diff);
      var /= count;
      double stdev = MathSqrt(var);

      //--- Normalized value: (diff - SMA(diff, 25)) / StdDev(diff, 25)
      double normalized = (stdev > 0) ? (diff - sma_diff) / stdev : 0;

      //--- Two-pole smooth filter
      if(!m_initialized)
      {
         m_smooth1 = normalized;
         m_smooth2 = normalized;
         m_initialized = true;
      }
      else
      {
         m_smooth1 = (1.0 - m_alpha) * m_smooth1 + m_alpha * normalized;
         m_smooth2 = (1.0 - m_alpha) * m_smooth2 + m_alpha * m_smooth1;
      }

      //--- Store in ring buffer
      double prev_osc = m_osc_value;
      double prev_lagged = m_osc_lagged;

      m_osc_buf[m_buf_idx % 8] = m_smooth2;
      m_osc_value = m_smooth2;

      //--- Lagged value (4 bars back)
      int lag_idx = (m_buf_idx - m_lag + 8) % 8;
      m_osc_lagged = m_osc_buf[lag_idx];
      m_buf_idx++;

      //--- Signal detection (crossover/crossunder in OB/OS zones)
      m_signal = DIR_NONE;

      if(m_bar_count <= m_lag + 2)
         return;  // Need enough history

      double prev_osc_val = m_osc_buf[(m_buf_idx - 2) % 8];
      int prev_lag_idx = (m_buf_idx - 1 - m_lag + 8) % 8;
      double prev_lagged_val = m_osc_buf[prev_lag_idx];

      //--- Crossover: osc crosses above lagged, and osc < 0 (oversold zone)
      bool crossover = (prev_osc_val <= prev_lagged_val) && (m_osc_value > m_osc_lagged);
      //--- Crossunder: osc crosses below lagged, and osc > 0 (overbought zone)
      bool crossunder = (prev_osc_val >= prev_lagged_val) && (m_osc_value < m_osc_lagged);

      if(crossover && m_osc_value < 0)
         m_signal = DIR_BUY;
      else if(crossunder && m_osc_value > 0)
         m_signal = DIR_SELL;
   }

   //+------------------------------------------------------------------+
   //| Bootstrap warmup                                                   |
   //+------------------------------------------------------------------+
   void Warmup(int bars = 300)
   {
      m_initialized = false;
      m_signal = DIR_NONE;
      m_bar_count = 0;
      m_buf_idx = 0;
      ArrayInitialize(m_osc_buf, 0);
      ArrayInitialize(m_close_buf, 0);
      ArrayInitialize(m_diff_buf, 0);
      for(int i = bars; i >= 1; i--)
         Update(i);
   }

   //--- Accessors
   int    GetSignal()     { return m_signal; }
   double GetValue()      { return m_osc_value; }
   double GetLagged()     { return m_osc_lagged; }
   bool   IsOversold()    { return m_osc_value < -0.5; }
   bool   IsOverbought()  { return m_osc_value > 0.5; }
};

#endif
