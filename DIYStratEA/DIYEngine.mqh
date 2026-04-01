//+------------------------------------------------------------------+
//| DIYEngine.mqh                                                     |
//| Range Filter + MA confluence engine for DIYConfluence EA          |
//| Ported core: Two-type range filter from DIY Custom Strategy       |
//| Confluence: SuperTrend, ZLEMA, RSI, Volume, ATR                  |
//+------------------------------------------------------------------+
#ifndef DIY_ENGINE_MQH
#define DIY_ENGINE_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/SuperTrend.mqh"
#include "../Indicators/ZeroLagEMA.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/ATRVolatility.mqh"

//+------------------------------------------------------------------+
//| CDIYEngine                                                         |
//| Primary: Range Filter direction flip                               |
//| Score: SuperTrend + ZLEMA + RSI + Volume + ATR                   |
//+------------------------------------------------------------------+
class CDIYEngine
{
private:
   //--- Range Filter state
   double m_rf_value;          // Current range filter value
   double m_rf_prev;           // Previous range filter value
   double m_hi_band;           // Upper band
   double m_lo_band;           // Lower band
   int    m_rf_direction;      // Current RF direction
   int    m_rf_prev_dir;       // Previous RF direction
   bool   m_rf_initialized;

   //--- Range Filter params
   int    m_rf_length;         // ATR period for range size
   double m_rf_qty;            // Range size quantity
   int    m_rf_smooth_n;       // Smoothing period

   //--- Confluence indicators
   CSuperTrend     m_supertrend;
   CZeroLagEMA     m_zlema;
   CRSISignal      m_rsi;
   CATRVolatility  m_atr_vol;

   //--- Settings
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int    m_threshold;
   string m_reject_reason;
   int    m_last_score;

   //--- ATR handle for range size
   int    m_atr_handle;

   double ReadATR(int shift)
   {
      double buf[];
      if(CopyBuffer(m_atr_handle, 0, shift, 1, buf) < 1) return 0;
      return buf[0];
   }

public:
   CDIYEngine() : m_rf_value(0), m_rf_prev(0), m_hi_band(0), m_lo_band(0),
                  m_rf_direction(DIR_NONE), m_rf_prev_dir(DIR_NONE),
                  m_rf_initialized(false), m_rf_length(100), m_rf_qty(2.618),
                  m_rf_smooth_n(5), m_atr_handle(INVALID_HANDLE),
                  m_threshold(60), m_last_score(0) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf,
             int rf_length, double rf_qty, int rf_smooth,
             int score_threshold)
   {
      m_symbol     = symbol;
      m_tf         = tf;
      m_rf_length  = rf_length;
      m_rf_qty     = rf_qty;
      m_rf_smooth_n = rf_smooth;
      m_threshold  = score_threshold;
      m_rf_initialized = false;

      m_atr_handle = iATR(symbol, tf, rf_length);
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("[DIYEngine] Failed to create ATR handle");
         return false;
      }

      //--- SuperTrend (10, 3.0)
      if(!m_supertrend.Init(symbol, tf, 10, 3.0))
         return false;

      //--- ZLEMA (70, 1.2)
      if(!m_zlema.Init(symbol, tf, 70, 1.2))
         return false;

      m_rsi.Init(20.0, false);
      m_atr_vol.Init(1.0, 1.5, 0.30);

      return true;
   }

   void Warmup(int bars = 500)
   {
      m_rf_initialized = false;
      m_rf_direction = DIR_NONE;

      m_supertrend.Warmup(bars);
      m_zlema.Warmup(bars);

      for(int i = bars; i >= 1; i--)
         UpdateRangeFilter(i);
   }

   void Deinit()
   {
      if(m_atr_handle != INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);
      m_supertrend.Deinit();
      m_zlema.Deinit();
   }

   //+------------------------------------------------------------------+
   //| Update Range Filter (Type 1 from PineScript rng_filt)            |
   //+------------------------------------------------------------------+
   void UpdateRangeFilter(int shift)
   {
      double high_val = iHigh(m_symbol, m_tf, shift);
      double low_val  = iLow(m_symbol, m_tf, shift);
      if(high_val == 0) return;

      //--- Range size = ATR * qty
      double atr = ReadATR(shift);
      double rng = atr * m_rf_qty;

      //--- Range Filter Type 1
      if(!m_rf_initialized)
      {
         m_rf_value = (high_val + low_val) / 2.0;
         m_rf_initialized = true;
      }
      else
      {
         m_rf_prev = m_rf_value;
         if(high_val - rng > m_rf_prev)
            m_rf_value = high_val - rng;
         else if(low_val + rng < m_rf_prev)
            m_rf_value = low_val + rng;
         else
            m_rf_value = m_rf_prev;
      }

      m_hi_band = m_rf_value + rng;
      m_lo_band = m_rf_value - rng;

      //--- Direction
      m_rf_prev_dir = m_rf_direction;
      if(m_rf_value > m_rf_prev)
         m_rf_direction = DIR_BUY;
      else if(m_rf_value < m_rf_prev)
         m_rf_direction = DIR_SELL;
      // else keep previous direction
   }

   //+------------------------------------------------------------------+
   //| Update all on new bar                                             |
   //+------------------------------------------------------------------+
   void Update(int shift = 1)
   {
      UpdateRangeFilter(shift);
      m_supertrend.Update(shift);
      m_zlema.Update(shift);
   }

   //+------------------------------------------------------------------+
   //| Check signal with scored confluence                                |
   //+------------------------------------------------------------------+
   int CheckSignal(CIndicatorManager &ind, string symbol, ENUM_TIMEFRAMES tf)
   {
      m_reject_reason = "";
      m_last_score = 0;

      //--- Primary: Range Filter direction flip
      if(m_rf_direction == DIR_NONE || m_rf_direction == m_rf_prev_dir)
      {
         m_reject_reason = "No Range Filter direction change";
         return DIR_NONE;
      }

      int signal = m_rf_direction;
      int score = 30;  // Primary

      //--- SuperTrend agreement
      if(m_supertrend.GetDirection() == signal)
         score += 20;

      //--- ZLEMA agreement
      if(m_zlema.GetDirection() == signal)
         score += 15;

      //--- RSI
      double rsi_curr = ind.GetRSI(1);
      double rsi_prev = ind.GetRSI(2);
      int rsi_sig = m_rsi.CheckRecovery(rsi_curr, rsi_prev);
      if(rsi_sig == signal || rsi_sig == DIR_NONE)
         score += 15;

      //--- Volume
      long vol_buf[];
      if(CopyTickVolume(symbol, tf, 1, 11, vol_buf) >= 11)
      {
         long cv = vol_buf[10];
         double avg = 0;
         for(int i = 0; i < 10; i++) avg += (double)vol_buf[i];
         avg /= 10;
         if(avg > 0 && (double)cv >= avg * 1.2)
            score += 10;
      }

      //--- ATR activity
      if(m_atr_vol.IsMarketActive(ind))
         score += 10;

      m_last_score = score;

      if(score < m_threshold)
      {
         m_reject_reason = "Score " + IntegerToString(score) + " < " + IntegerToString(m_threshold);
         return DIR_NONE;
      }

      return signal;
   }

   //--- Accessors
   string GetRejectReason() { return m_reject_reason; }
   int    GetLastScore()    { return m_last_score; }
   double GetRFValue()      { return m_rf_value; }
   double GetHiBand()       { return m_hi_band; }
   double GetLoBand()       { return m_lo_band; }

   double GetLotFactor()
   {
      if(m_last_score >= 85) return 1.00;
      if(m_last_score >= 75) return 0.75;
      if(m_last_score >= 65) return 0.50;
      return 0.0;
   }
};

#endif
