//+------------------------------------------------------------------+
//| TrendFilter.mqh                                                   |
//| EMA(200) M15 trend direction filter for WakaScalp                |
//| Prevents counter-trend mean-reversion entries                     |
//+------------------------------------------------------------------+
#ifndef TREND_FILTER_MQH
#define TREND_FILTER_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"

//+------------------------------------------------------------------+
//| CTrendFilter                                                      |
//| Layer 1: Macro trend via EMA(200) on M15                         |
//| - Price above EMA + upward slope → BUY only                      |
//| - Price below EMA + downward slope → SELL only                   |
//| - Price near EMA (chop zone) → NO trades                         |
//+------------------------------------------------------------------+
class CTrendFilter
{
private:
   int    m_slope_bars;    // Bars back for slope detection
   double m_chop_mult;     // ATR multiplier for chop zone (default 0.5)

public:
   CTrendFilter() : m_slope_bars(5), m_chop_mult(0.5) {}

   void Init(int slope_bars = 5, double chop_mult = 0.5)
   {
      m_slope_bars = slope_bars;
      m_chop_mult  = chop_mult;
   }

   //+------------------------------------------------------------------+
   //| Get trend direction                                               |
   //| Returns DIR_BUY, DIR_SELL, or DIR_NONE (chop zone)              |
   //+------------------------------------------------------------------+
   int GetDirection(CIndicatorManager &ind, double current_price, double atr_value)
   {
      double ema_current, ema_previous;
      if(!ind.GetEMATrendValues(ema_current, ema_previous, m_slope_bars))
         return DIR_NONE;

      //--- Chop zone: price within chop_mult * ATR of EMA
      double chop_zone = m_chop_mult * atr_value;
      if(MathAbs(current_price - ema_current) < chop_zone)
         return DIR_NONE;

      //--- Determine slope
      bool slope_up   = (ema_current > ema_previous);
      bool slope_down = (ema_current < ema_previous);

      //--- Price above EMA with upward slope = bullish
      if(current_price > ema_current && slope_up)
         return DIR_BUY;

      //--- Price below EMA with downward slope = bearish
      if(current_price < ema_current && slope_down)
         return DIR_SELL;

      //--- Conflicting signals (price above but slope down, etc.) = no trend
      return DIR_NONE;
   }

   //--- Get raw EMA value for panel display
   double GetEMAValue(CIndicatorManager &ind)
   {
      return ind.GetEMATrend(1);
   }
};

#endif
