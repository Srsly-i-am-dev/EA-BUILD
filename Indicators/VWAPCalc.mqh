//+------------------------------------------------------------------+
//| VWAPCalc.mqh                                                      |
//| Custom VWAP implementation for MT5                                |
//| VWAP = cumSum(TypicalPrice * Volume) / cumSum(Volume)            |
//| Resets daily at session boundary                                  |
//+------------------------------------------------------------------+
#ifndef VWAP_CALC_MQH
#define VWAP_CALC_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CVWAPCalc                                                         |
//+------------------------------------------------------------------+
class CVWAPCalc
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;

   //--- State
   double            m_vwap;
   double            m_prev_vwap;     // Previous bar VWAP for slope
   double            m_cum_pv;        // Cumulative price * volume
   double            m_cum_vol;       // Cumulative volume
   datetime          m_session_day;   // Current session date
   bool              m_valid;

public:
   CVWAPCalc() : m_vwap(0), m_prev_vwap(0), m_cum_pv(0),
                 m_cum_vol(0), m_session_day(0), m_valid(false) {}

   void Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol;
      m_tf     = tf;
      m_valid  = false;
   }

   //+------------------------------------------------------------------+
   //| Calculate VWAP for current session                                |
   //| Must be called on each new bar                                    |
   //+------------------------------------------------------------------+
   void Calculate(int shift = 1)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      //--- Find today's session start by scanning back to day boundary
      datetime bar_time = iTime(m_symbol, m_tf, shift);
      if(bar_time == 0) return;

      MqlDateTime dt;
      TimeToStruct(bar_time, dt);
      datetime today_start = StringToTime(IntegerToString(dt.year) + "."
                           + IntegerToString(dt.mon) + "."
                           + IntegerToString(dt.day));

      //--- If new day, reset accumulators
      if(today_start != m_session_day)
      {
         m_session_day = today_start;
         m_cum_pv  = 0;
         m_cum_vol = 0;
         m_prev_vwap = 0;
      }

      //--- Get current bar data
      double high  = iHigh(m_symbol, m_tf, shift);
      double low   = iLow(m_symbol, m_tf, shift);
      double close = iClose(m_symbol, m_tf, shift);
      if(high == 0) return;

      long vol_buf[];
      if(CopyTickVolume(m_symbol, m_tf, shift, 1, vol_buf) < 1) return;
      double vol = (double)vol_buf[0];
      if(vol <= 0) vol = 1;

      double typical_price = (high + low + close) / 3.0;

      m_prev_vwap = m_vwap;
      m_cum_pv  += typical_price * vol;
      m_cum_vol += vol;
      m_vwap = m_cum_pv / m_cum_vol;
      m_valid = true;
   }

   //+------------------------------------------------------------------+
   //| Full recalculation from session start (call on init/day change)   |
   //+------------------------------------------------------------------+
   void Recalculate(int max_bars = 500)
   {
      m_cum_pv  = 0;
      m_cum_vol = 0;
      m_valid   = false;

      //--- Find today's date from bar at shift=1
      datetime bar_time = iTime(m_symbol, m_tf, 1);
      if(bar_time == 0) return;

      MqlDateTime dt;
      TimeToStruct(bar_time, dt);
      m_session_day = StringToTime(IntegerToString(dt.year) + "."
                    + IntegerToString(dt.mon) + "."
                    + IntegerToString(dt.day));

      //--- Scan backwards to find session start bar
      int start_shift = -1;
      for(int i = 1; i < max_bars; i++)
      {
         datetime t = iTime(m_symbol, m_tf, i);
         if(t < m_session_day)
         {
            start_shift = i - 1;
            break;
         }
      }
      if(start_shift < 1) start_shift = 1;

      //--- Accumulate from session start to current
      for(int i = start_shift; i >= 1; i--)
      {
         double high  = iHigh(m_symbol, m_tf, i);
         double low   = iLow(m_symbol, m_tf, i);
         double close = iClose(m_symbol, m_tf, i);
         if(high == 0) continue;

         long vol_buf[];
         if(CopyTickVolume(m_symbol, m_tf, i, 1, vol_buf) < 1) continue;
         double vol = (double)vol_buf[0];
         if(vol <= 0) vol = 1;

         double tp = (high + low + close) / 3.0;
         m_cum_pv  += tp * vol;
         m_cum_vol += vol;
      }

      if(m_cum_vol > 0)
      {
         m_vwap = m_cum_pv / m_cum_vol;
         m_prev_vwap = m_vwap;
         m_valid = true;
      }
   }

   //+------------------------------------------------------------------+
   //| Directional bias: price vs VWAP                                   |
   //+------------------------------------------------------------------+
   int GetBias(double current_price)
   {
      if(!m_valid || m_vwap <= 0) return DIR_NONE;
      if(current_price > m_vwap) return DIR_BUY;
      if(current_price < m_vwap) return DIR_SELL;
      return DIR_NONE;
   }

   //+------------------------------------------------------------------+
   //| Is VWAP flat (slope too small → choppy, skip trading)            |
   //+------------------------------------------------------------------+
   bool IsFlat(double min_slope_points = 0.10)
   {
      if(!m_valid || m_prev_vwap <= 0) return true;
      return (MathAbs(m_vwap - m_prev_vwap) < min_slope_points);
   }

   //--- Accessors
   double GetValue()   { return m_vwap; }
   bool   IsValid()    { return m_valid; }
};

#endif
