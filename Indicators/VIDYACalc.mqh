//+------------------------------------------------------------------+
//| VIDYACalc.mqh                                                     |
//| Variable Index Dynamic Average with adaptive ATR bands            |
//| Ported from BigBeluga PineScript implementation                   |
//| Signal: Trend flip when price crosses upper/lower band            |
//+------------------------------------------------------------------+
#ifndef VIDYA_CALC_MQH
#define VIDYA_CALC_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CVIDYACalc                                                         |
//+------------------------------------------------------------------+
class CVIDYACalc
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_vidya_length;     // VIDYA length (default 10)
   int               m_momentum_length;  // Momentum length (default 20)
   double            m_band_distance;    // Band distance factor (default 2.0)

   //--- Indicator handles
   int               m_atr_handle;       // ATR(200) handle

   //--- Internal state
   double            m_vidya_raw;        // Raw VIDYA value
   double            m_vidya;            // Smoothed VIDYA (SMA 15 of raw)
   bool              m_trend_up;         // Current trend direction
   int               m_prev_trend;       // Previous trend (for detecting flips)
   int               m_signal;           // DIR_BUY, DIR_SELL, or DIR_NONE
   bool              m_initialized;

   //--- Momentum buffers (for CMO calculation)
   double            m_close_buf[];      // Close price ring buffer
   int               m_buf_size;
   int               m_buf_idx;
   int               m_bar_count;

   //--- VIDYA SMA buffer (15-period smoothing)
   double            m_vidya_sma_buf[15];
   int               m_sma_idx;

   //--- Band values
   double            m_upper_band;
   double            m_lower_band;
   double            m_smoothed_level;   // Trend-following level

   double ReadATR(int shift)
   {
      double buf[];
      if(CopyBuffer(m_atr_handle, 0, shift, 1, buf) < 1) return 0;
      return buf[0];
   }

public:
   CVIDYACalc() : m_atr_handle(INVALID_HANDLE), m_vidya_length(10),
                  m_momentum_length(20), m_band_distance(2.0),
                  m_vidya_raw(0), m_vidya(0), m_trend_up(false),
                  m_prev_trend(DIR_NONE), m_signal(DIR_NONE),
                  m_initialized(false), m_buf_idx(0), m_bar_count(0),
                  m_sma_idx(0), m_upper_band(0), m_lower_band(0),
                  m_smoothed_level(0) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf,
             int vidya_len = 10, int momentum_len = 20, double band_dist = 2.0)
   {
      m_symbol           = symbol;
      m_tf               = tf;
      m_vidya_length     = vidya_len;
      m_momentum_length  = momentum_len;
      m_band_distance    = band_dist;
      m_initialized      = false;
      m_bar_count        = 0;
      m_buf_idx          = 0;
      m_sma_idx          = 0;
      m_trend_up         = false;

      m_buf_size = momentum_len + 2;
      ArrayResize(m_close_buf, m_buf_size);
      ArrayInitialize(m_close_buf, 0);
      ArrayInitialize(m_vidya_sma_buf, 0);

      m_atr_handle = iATR(symbol, tf, 200);
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("[VIDYA] Failed to create ATR(200) handle");
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
   //| Update on new bar                                                  |
   //+------------------------------------------------------------------+
   void Update(int shift = 1)
   {
      double close_val = iClose(m_symbol, m_tf, shift);
      if(close_val == 0) return;

      m_bar_count++;

      //--- Store close in ring buffer
      m_close_buf[m_buf_idx % m_buf_size] = close_val;
      m_buf_idx++;

      if(m_bar_count < 2) return;

      //--- Calculate Chande Momentum Oscillator (CMO)
      int look = MathMin(m_bar_count - 1, m_momentum_length);
      double sum_pos = 0, sum_neg = 0;

      for(int i = 0; i < look; i++)
      {
         int curr_idx = (m_buf_idx - 1 - i + m_buf_size * 10) % m_buf_size;
         int prev_idx = (m_buf_idx - 2 - i + m_buf_size * 10) % m_buf_size;
         double change = m_close_buf[curr_idx] - m_close_buf[prev_idx];
         if(change >= 0)
            sum_pos += change;
         else
            sum_neg += (-change);
      }

      double denom = sum_pos + sum_neg;
      double abs_cmo = (denom > 0) ? MathAbs(100.0 * (sum_pos - sum_neg) / denom) : 0;

      //--- VIDYA recursive formula
      double alpha = 2.0 / (m_vidya_length + 1.0);
      double sc = alpha * abs_cmo / 100.0;

      if(!m_initialized)
      {
         m_vidya_raw = close_val;
         m_initialized = true;
      }
      else
      {
         m_vidya_raw = sc * close_val + (1.0 - sc) * m_vidya_raw;
      }

      //--- SMA(15) smoothing of raw VIDYA
      m_vidya_sma_buf[m_sma_idx % 15] = m_vidya_raw;
      m_sma_idx++;
      int sma_count = MathMin(m_sma_idx, 15);
      double sma_sum = 0;
      for(int i = 0; i < sma_count; i++)
         sma_sum += m_vidya_sma_buf[i];
      m_vidya = sma_sum / sma_count;

      //--- ATR bands
      double atr = ReadATR(shift);
      m_upper_band = m_vidya + atr * m_band_distance;
      m_lower_band = m_vidya - atr * m_band_distance;

      //--- Trend detection via band crossover
      m_prev_trend = m_trend_up ? DIR_BUY : DIR_SELL;

      if(close_val > m_upper_band)
         m_trend_up = true;
      else if(close_val < m_lower_band)
         m_trend_up = false;

      int curr_trend = m_trend_up ? DIR_BUY : DIR_SELL;

      //--- Smoothed level (follows lower band in uptrend, upper band in downtrend)
      m_smoothed_level = m_trend_up ? m_lower_band : m_upper_band;

      //--- Signal on trend flip
      m_signal = DIR_NONE;
      if(curr_trend != m_prev_trend)
      {
         m_signal = curr_trend;
      }
   }

   //+------------------------------------------------------------------+
   //| Bootstrap warmup                                                   |
   //+------------------------------------------------------------------+
   void Warmup(int bars = 500)
   {
      m_initialized = false;
      m_signal = DIR_NONE;
      m_bar_count = 0;
      m_buf_idx = 0;
      m_sma_idx = 0;
      m_trend_up = false;
      ArrayInitialize(m_close_buf, 0);
      ArrayInitialize(m_vidya_sma_buf, 0);
      for(int i = bars; i >= 1; i--)
         Update(i);
   }

   //--- Accessors
   int    GetSignal()         { return m_signal; }
   int    GetDirection()      { return m_trend_up ? DIR_BUY : DIR_SELL; }
   double GetValue()          { return m_vidya; }
   double GetUpperBand()      { return m_upper_band; }
   double GetLowerBand()      { return m_lower_band; }
   double GetSmoothedLevel()  { return m_smoothed_level; }
   bool   IsTrendUp()         { return m_trend_up; }
};

#endif
