//+------------------------------------------------------------------+
//| StdDevRegime.mqh                                                  |
//| Volatility regime classification via StdDev vs its own SMA        |
//| LOW_VOL = mean-reversion safe, HIGH/EXTREME = skip                |
//+------------------------------------------------------------------+
#ifndef STDDEV_REGIME_MQH
#define STDDEV_REGIME_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| Volatility regime enum                                            |
//+------------------------------------------------------------------+
enum ENUM_VOL_REGIME
{
   VOL_LOW      = 0,   // StdDev < 0.8 * SMA(StdDev) — quiet market
   VOL_NORMAL   = 1,   // StdDev between 0.8-1.2 * SMA — normal
   VOL_HIGH     = 2,   // StdDev between 1.2-2.0 * SMA — elevated
   VOL_EXTREME  = 3    // StdDev > 2.0 * SMA — extreme (news/event)
};

//+------------------------------------------------------------------+
//| CStdDevRegime                                                     |
//+------------------------------------------------------------------+
class CStdDevRegime
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_stddev_handle;
   int               m_stddev_period;
   int               m_sma_period;    // SMA of StdDev for baseline

   double ReadStdDev(int shift)
   {
      double buf[];
      if(m_stddev_handle == INVALID_HANDLE) return 0;
      if(CopyBuffer(m_stddev_handle, 0, shift, 1, buf) < 1) return 0;
      return buf[0];
   }

public:
   CStdDevRegime() : m_stddev_handle(INVALID_HANDLE),
                     m_stddev_period(20), m_sma_period(50) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int stddev_period = 20, int sma_period = 50)
   {
      m_symbol        = symbol;
      m_tf            = tf;
      m_stddev_period = stddev_period;
      m_sma_period    = sma_period;

      m_stddev_handle = iStdDev(symbol, tf, stddev_period, 0, MODE_SMA, PRICE_CLOSE);
      if(m_stddev_handle == INVALID_HANDLE)
      {
         Print("[StdDevRegime] Failed to create StdDev(", stddev_period, ") handle");
         return false;
      }
      return true;
   }

   void Deinit()
   {
      if(m_stddev_handle != INVALID_HANDLE)
         IndicatorRelease(m_stddev_handle);
      m_stddev_handle = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Get current volatility regime                                     |
   //+------------------------------------------------------------------+
   ENUM_VOL_REGIME GetRegime(int shift = 1)
   {
      double current = ReadStdDev(shift);
      if(current <= 0) return VOL_NORMAL;

      //--- Calculate SMA of StdDev over sma_period bars
      double sum = 0;
      int count = 0;
      for(int i = shift; i < shift + m_sma_period; i++)
      {
         double val = ReadStdDev(i);
         if(val > 0)
         {
            sum += val;
            count++;
         }
      }
      if(count <= 0) return VOL_NORMAL;

      double avg = sum / count;
      double ratio = current / avg;

      if(ratio < 0.8)  return VOL_LOW;
      if(ratio <= 1.2)  return VOL_NORMAL;
      if(ratio <= 2.0)  return VOL_HIGH;
      return VOL_EXTREME;
   }

   //+------------------------------------------------------------------+
   //| Is mean-reversion safe? (LOW or NORMAL vol)                      |
   //+------------------------------------------------------------------+
   bool IsMeanReversionSafe(int shift = 1)
   {
      ENUM_VOL_REGIME regime = GetRegime(shift);
      return (regime == VOL_LOW || regime == VOL_NORMAL);
   }

   //+------------------------------------------------------------------+
   //| Get raw ratio: current StdDev / SMA(StdDev)                     |
   //+------------------------------------------------------------------+
   double GetRatio(int shift = 1)
   {
      double current = ReadStdDev(shift);
      if(current <= 0) return 1.0;

      double sum = 0;
      int count = 0;
      for(int i = shift; i < shift + m_sma_period; i++)
      {
         double val = ReadStdDev(i);
         if(val > 0) { sum += val; count++; }
      }
      if(count <= 0) return 1.0;
      return current / (sum / count);
   }

   //--- Current StdDev value
   double GetValue(int shift = 1) { return ReadStdDev(shift); }
};

#endif
