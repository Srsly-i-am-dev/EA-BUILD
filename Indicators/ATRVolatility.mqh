//+------------------------------------------------------------------+
//| ATRVolatility.mqh                                                 |
//| ATR ratio calculation for smart distance — shared                 |
//+------------------------------------------------------------------+
#ifndef ATR_VOLATILITY_MQH
#define ATR_VOLATILITY_MQH

#include "IndicatorManager.mqh"

//+------------------------------------------------------------------+
//| CATRVolatility                                                    |
//| WakaGrid: ATR(96)/ATR(672) ratio clamped [1.0, 1.5] for grid     |
//| WakaScalp: ATR(14) on M5 for TP/SL sizing + activity gate        |
//+------------------------------------------------------------------+
class CATRVolatility
{
private:
   double m_min_multiplier;  // Lower clamp (default 1.0)
   double m_max_multiplier;  // Upper clamp (default 1.5)
   double m_min_atr_gate;    // Minimum ATR for trading (WakaScalp)

public:
   CATRVolatility() : m_min_multiplier(1.0), m_max_multiplier(1.5), m_min_atr_gate(0.0) {}

   void Init(double min_mult = 1.0, double max_mult = 1.5, double min_atr = 0.0)
   {
      m_min_multiplier = min_mult;
      m_max_multiplier = max_mult;
      m_min_atr_gate   = min_atr;
   }

   //+------------------------------------------------------------------+
   //| WakaGrid: Smart distance multiplier                               |
   //| Returns clamp(ATR_short / ATR_long, min, max)                    |
   //+------------------------------------------------------------------+
   double GetSmartMultiplier(CIndicatorManager &ind)
   {
      double atr_short = ind.GetATRShort(1);
      double atr_long  = ind.GetATRLong(1);

      if(atr_long <= 0) return m_min_multiplier;

      double ratio = atr_short / atr_long;
      return MathMax(m_min_multiplier, MathMin(m_max_multiplier, ratio));
   }

   //+------------------------------------------------------------------+
   //| WakaScalp: ATR activity gate                                      |
   //| Returns true if current ATR exceeds minimum threshold             |
   //+------------------------------------------------------------------+
   bool IsMarketActive(CIndicatorManager &ind)
   {
      if(m_min_atr_gate <= 0) return true;
      return (ind.GetATRShort(1) >= m_min_atr_gate);
   }

   //--- Get raw ATR values
   double GetATRShort(CIndicatorManager &ind) { return ind.GetATRShort(1); }
   double GetATRLong(CIndicatorManager &ind)  { return ind.GetATRLong(1); }

   //--- Accessors
   double MinMultiplier() { return m_min_multiplier; }
   double MaxMultiplier() { return m_max_multiplier; }
   double MinATRGate()    { return m_min_atr_gate; }
};

#endif
