//+------------------------------------------------------------------+
//| SuperTrend.mqh                                                    |
//| ATR-based trend indicator with band clamping                      |
//| Used by GoldPattern + GoldBB as trend confirmation filter         |
//+------------------------------------------------------------------+
#ifndef SUPERTREND_MQH
#define SUPERTREND_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CSuperTrend                                                       |
//| UpperBand = Median + Mult * ATR                                   |
//| LowerBand = Median - Mult * ATR                                   |
//| Band clamping: Upper only moves DOWN, Lower only moves UP         |
//| Direction flips when Close crosses opposite band                  |
//+------------------------------------------------------------------+
class CSuperTrend
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_atr_handle;
   int               m_atr_period;
   double            m_multiplier;

   //--- State
   double            m_upper_band;
   double            m_lower_band;
   double            m_st_value;      // Current SuperTrend line value
   int               m_direction;     // DIR_BUY or DIR_SELL
   bool              m_initialized;

   double ReadATR(int shift)
   {
      double buf[];
      if(CopyBuffer(m_atr_handle, 0, shift, 1, buf) < 1) return 0;
      return buf[0];
   }

public:
   CSuperTrend() : m_atr_handle(INVALID_HANDLE), m_atr_period(7),
                   m_multiplier(2.0), m_upper_band(0), m_lower_band(0),
                   m_st_value(0), m_direction(DIR_BUY), m_initialized(false) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int atr_period, double multiplier)
   {
      m_symbol     = symbol;
      m_tf         = tf;
      m_atr_period = atr_period;
      m_multiplier = multiplier;
      m_initialized = false;

      m_atr_handle = iATR(symbol, tf, atr_period);
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("[SuperTrend] Failed to create ATR(", atr_period, ") handle");
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
   //| Update SuperTrend calculation                                     |
   //| Call on each new bar with shift=1 (completed bar)                 |
   //+------------------------------------------------------------------+
   void Update(int shift = 1)
   {
      double atr = ReadATR(shift);
      if(atr <= 0) return;

      double high  = iHigh(m_symbol, m_tf, shift);
      double low   = iLow(m_symbol, m_tf, shift);
      double close = iClose(m_symbol, m_tf, shift);
      double median = (high + low) / 2.0;

      double new_upper = median + m_multiplier * atr;
      double new_lower = median - m_multiplier * atr;

      if(!m_initialized)
      {
         m_upper_band = new_upper;
         m_lower_band = new_lower;
         m_direction  = (close > median) ? DIR_BUY : DIR_SELL;
         m_st_value   = (m_direction == DIR_BUY) ? m_lower_band : m_upper_band;
         m_initialized = true;
         return;
      }

      //--- Band clamping
      double prev_close = iClose(m_symbol, m_tf, shift + 1);

      // Upper can only move DOWN (tighten) when previous close was below
      if(new_upper < m_upper_band || prev_close > m_upper_band)
         m_upper_band = new_upper;

      // Lower can only move UP (tighten) when previous close was above
      if(new_lower > m_lower_band || prev_close < m_lower_band)
         m_lower_band = new_lower;

      //--- Direction flip
      if(m_direction == DIR_SELL && close > m_upper_band)
         m_direction = DIR_BUY;
      else if(m_direction == DIR_BUY && close < m_lower_band)
         m_direction = DIR_SELL;

      //--- SuperTrend line value
      m_st_value = (m_direction == DIR_BUY) ? m_lower_band : m_upper_band;
   }

   //+------------------------------------------------------------------+
   //| Bootstrap: run Update over N historical bars to warm up state     |
   //+------------------------------------------------------------------+
   void Warmup(int bars = 200)
   {
      m_initialized = false;
      for(int i = bars; i >= 1; i--)
         Update(i);
   }

   //--- Accessors
   int    GetDirection()  { return m_direction; }
   double GetStopLevel()  { return m_st_value; }
   double GetUpperBand()  { return m_upper_band; }
   double GetLowerBand()  { return m_lower_band; }
   bool   IsInitialized() { return m_initialized; }
};

#endif
