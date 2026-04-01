//+------------------------------------------------------------------+
//| FibLevels.mqh                                                     |
//| Dynamic Fibonacci retracement + extension levels                  |
//| Finds swing high/low over N bars, computes fib levels             |
//+------------------------------------------------------------------+
#ifndef FIB_LEVELS_MQH
#define FIB_LEVELS_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CFibLevels                                                        |
//+------------------------------------------------------------------+
class CFibLevels
{
private:
   int    m_lookback;     // Bars to scan for high/low
   int    m_skip;         // Skip N recent bars (reduce repainting)

   //--- Calculated levels
   double m_swing_high;
   double m_swing_low;
   double m_range;

   //--- Retracement levels (from high towards low for bearish, low towards high for bullish)
   double m_fib_236;
   double m_fib_382;
   double m_fib_500;
   double m_fib_618;
   double m_fib_786;

   //--- Extension levels (beyond the swing range)
   double m_ext_1272;
   double m_ext_1618;

   bool   m_valid;

public:
   CFibLevels() : m_lookback(50), m_skip(3), m_swing_high(0), m_swing_low(0),
                  m_range(0), m_valid(false) {}

   void Init(int lookback_bars = 50, int skip_bars = 3)
   {
      m_lookback = lookback_bars;
      m_skip     = skip_bars;
      m_valid    = false;
   }

   //+------------------------------------------------------------------+
   //| Calculate Fibonacci levels from recent swing high/low             |
   //+------------------------------------------------------------------+
   bool Calculate(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_valid = false;
      int start = m_skip + 1;
      int end   = start + m_lookback;

      m_swing_high = -DBL_MAX;
      m_swing_low  = DBL_MAX;

      for(int i = start; i < end; i++)
      {
         double h = iHigh(symbol, tf, i);
         double l = iLow(symbol, tf, i);
         if(h == 0) continue;
         if(h > m_swing_high) m_swing_high = h;
         if(l < m_swing_low)  m_swing_low  = l;
      }

      m_range = m_swing_high - m_swing_low;
      if(m_range <= 0) return false;

      //--- Retracement from high (bearish pull levels)
      m_fib_236 = m_swing_high - m_range * 0.236;
      m_fib_382 = m_swing_high - m_range * 0.382;
      m_fib_500 = m_swing_high - m_range * 0.500;
      m_fib_618 = m_swing_high - m_range * 0.618;
      m_fib_786 = m_swing_high - m_range * 0.786;

      //--- Extension levels
      m_ext_1272 = m_swing_high + m_range * 0.272;  // 127.2% of range above high
      m_ext_1618 = m_swing_high + m_range * 0.618;  // 161.8% of range above high

      m_valid = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Get TP target based on Fib extension                              |
   //| For BUY: 127.2% extension above swing high                       |
   //| For SELL: 127.2% extension below swing low                       |
   //+------------------------------------------------------------------+
   double GetTPTarget(double entry_price, int direction)
   {
      if(!m_valid) return 0;

      if(direction == DIR_BUY)
         return m_swing_high + m_range * 0.272;   // 127.2% extension above
      else
         return m_swing_low - m_range * 0.272;    // 127.2% extension below
   }

   //+------------------------------------------------------------------+
   //| Get extended TP at 161.8%                                         |
   //+------------------------------------------------------------------+
   double GetExtendedTP(double entry_price, int direction)
   {
      if(!m_valid) return 0;

      if(direction == DIR_BUY)
         return m_swing_high + m_range * 0.618;
      else
         return m_swing_low - m_range * 0.618;
   }

   //+------------------------------------------------------------------+
   //| Get SL level based on Fib 78.6% or 100% retracement             |
   //+------------------------------------------------------------------+
   double GetSLLevel(double entry_price, int direction)
   {
      if(!m_valid) return 0;

      if(direction == DIR_BUY)
         return m_fib_786;   // SL below 78.6% retracement
      else
         return m_swing_high - m_range * (1.0 - 0.786);  // Mirror for sells
   }

   //+------------------------------------------------------------------+
   //| Get nearest Fib level to a given price                            |
   //+------------------------------------------------------------------+
   double GetNearestLevel(double price)
   {
      if(!m_valid) return 0;

      double levels[] = {m_swing_high, m_fib_236, m_fib_382, m_fib_500,
                         m_fib_618, m_fib_786, m_swing_low};
      double nearest = levels[0];
      double min_dist = MathAbs(price - levels[0]);

      for(int i = 1; i < ArraySize(levels); i++)
      {
         double dist = MathAbs(price - levels[i]);
         if(dist < min_dist)
         {
            min_dist = dist;
            nearest = levels[i];
         }
      }
      return nearest;
   }

   //--- Accessors
   double SwingHigh() { return m_swing_high; }
   double SwingLow()  { return m_swing_low; }
   double Range()     { return m_range; }
   double Fib236()    { return m_fib_236; }
   double Fib382()    { return m_fib_382; }
   double Fib500()    { return m_fib_500; }
   double Fib618()    { return m_fib_618; }
   double Fib786()    { return m_fib_786; }
   double Ext1272()   { return m_ext_1272; }
   double Ext1618()   { return m_ext_1618; }
   bool   IsValid()   { return m_valid; }
};

#endif
