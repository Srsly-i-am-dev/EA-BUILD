//+------------------------------------------------------------------+
//| BollingerCalc.mqh                                                 |
//| Manual Bollinger Band calculation using MA + StdDev               |
//| Avoids iBands() multi-currency issues in MQL5                     |
//+------------------------------------------------------------------+
#ifndef BOLLINGER_CALC_MQH
#define BOLLINGER_CALC_MQH

#include "IndicatorManager.mqh"

//+------------------------------------------------------------------+
//| CBollingerCalc                                                    |
//| Upper = MA + mult * StdDev                                       |
//| Lower = MA - mult * StdDev                                       |
//+------------------------------------------------------------------+
class CBollingerCalc
{
private:
   double m_deviation_mult;   // Standard: 2.0

public:
   CBollingerCalc() : m_deviation_mult(2.0) {}

   void Init(double deviation_mult = 2.0)
   {
      m_deviation_mult = deviation_mult;
   }

   //+------------------------------------------------------------------+
   //| Calculate BB values for a given shift                             |
   //+------------------------------------------------------------------+
   void Calculate(CIndicatorManager &ind, int shift,
                  double &upper, double &middle, double &lower, double &width)
   {
      middle = ind.GetMA(shift);
      double stddev = ind.GetStdDev(shift);

      upper = middle + m_deviation_mult * stddev;
      lower = middle - m_deviation_mult * stddev;
      width = upper - lower;
   }

   //--- Quick access to individual values
   double GetUpper(CIndicatorManager &ind, int shift = 1)
   {
      return ind.GetMA(shift) + m_deviation_mult * ind.GetStdDev(shift);
   }

   double GetLower(CIndicatorManager &ind, int shift = 1)
   {
      return ind.GetMA(shift) - m_deviation_mult * ind.GetStdDev(shift);
   }

   double GetMiddle(CIndicatorManager &ind, int shift = 1)
   {
      return ind.GetMA(shift);
   }

   double GetWidth(CIndicatorManager &ind, int shift = 1)
   {
      return 2.0 * m_deviation_mult * ind.GetStdDev(shift);
   }

   //+------------------------------------------------------------------+
   //| WakaScalp: Close-back-inside detection                           |
   //| Buy: prev close was below lower BB, current close is back above  |
   //| Sell: prev close was above upper BB, current close is back below |
   //| Returns DIR_BUY, DIR_SELL, or DIR_NONE                           |
   //+------------------------------------------------------------------+
   int CheckCloseBackInside(CIndicatorManager &ind,
                            double close_current, double close_previous)
   {
      double upper_prev = GetUpper(ind, 2);  // BB at bar[2] (previous completed)
      double lower_prev = GetLower(ind, 2);
      double upper_curr = GetUpper(ind, 1);  // BB at bar[1] (most recent completed)
      double lower_curr = GetLower(ind, 1);

      // Buy: was outside lower, now back inside
      if(close_previous < lower_prev && close_current >= lower_curr)
         return DIR_BUY;

      // Sell: was outside upper, now back inside
      if(close_previous > upper_prev && close_current <= upper_curr)
         return DIR_SELL;

      return DIR_NONE;
   }

   //+------------------------------------------------------------------+
   //| WakaScalp: BB squeeze detection                                   |
   //| Returns true if BB width < threshold (breakout imminent)         |
   //+------------------------------------------------------------------+
   bool IsSqueezed(CIndicatorManager &ind, double atr_long_value, double squeeze_pct = 0.5)
   {
      double bb_width = GetWidth(ind, 1);
      if(atr_long_value <= 0) return false;
      return (bb_width < atr_long_value * squeeze_pct);
   }

   double DeviationMult() { return m_deviation_mult; }
};

#endif
