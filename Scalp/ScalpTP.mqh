//+------------------------------------------------------------------+
//| ScalpTP.mqh                                                       |
//| ATR-based + spread-based dynamic TP/SL for WakaScalp             |
//+------------------------------------------------------------------+
#ifndef SCALP_TP_MQH
#define SCALP_TP_MQH

#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/BollingerCalc.mqh"
#include "../Utils/SymbolInfo.mqh"

//+------------------------------------------------------------------+
//| CScalpTP                                                          |
//| Dual-mode: ATR-based primary, spread-based fallback               |
//+------------------------------------------------------------------+
class CScalpTP
{
private:
   //--- ATR mode
   double m_tp_atr_mult;
   double m_sl_atr_mult;

   //--- Spread mode (fallback)
   double m_tp_spread_mult;
   double m_sl_spread_mult;

   //--- Floors and ceilings (in points)
   double m_min_tp_pts;
   double m_max_tp_pts;
   double m_min_sl_pts;
   double m_max_sl_pts;
   double m_min_rr;

   //--- Smart TP (BB middle)
   bool   m_smart_tp;

   //--- Calculated values (available after Calculate)
   double m_tp_distance;   // In price units
   double m_sl_distance;   // In price units

public:
   CScalpTP() : m_tp_atr_mult(0.75), m_sl_atr_mult(1.5),
                m_tp_spread_mult(8.0), m_sl_spread_mult(6.0),
                m_min_tp_pts(30), m_max_tp_pts(150),
                m_min_sl_pts(40), m_max_sl_pts(200),
                m_min_rr(0.4), m_smart_tp(true),
                m_tp_distance(0), m_sl_distance(0) {}

   void Init(double tp_atr, double sl_atr,
             double tp_spread, double sl_spread,
             double min_tp, double max_tp,
             double min_sl, double max_sl,
             double min_rr, bool smart_tp)
   {
      m_tp_atr_mult    = tp_atr;
      m_sl_atr_mult    = sl_atr;
      m_tp_spread_mult = tp_spread;
      m_sl_spread_mult = sl_spread;
      m_min_tp_pts     = min_tp;
      m_max_tp_pts     = max_tp;
      m_min_sl_pts     = min_sl;
      m_max_sl_pts     = max_sl;
      m_min_rr         = min_rr;
      m_smart_tp       = smart_tp;
   }

   //+------------------------------------------------------------------+
   //| Calculate TP/SL distances                                         |
   //| Returns false if trade should be skipped (R:R too low)           |
   //+------------------------------------------------------------------+
   bool Calculate(CIndicatorManager &ind, CSymbolHelper &sym,
                  CBollingerCalc &bb, double entry_price, int direction)
   {
      double point = sym.Point();
      double atr   = ind.GetATRShort(1);
      double spread_price = sym.GetSpreadPrice();

      //--- Mode A: ATR-based (primary)
      double tp_atr = atr * m_tp_atr_mult;
      double sl_atr = atr * m_sl_atr_mult;

      //--- Mode B: Spread-based (fallback)
      double tp_spread = spread_price * m_tp_spread_mult;
      double sl_spread = spread_price * m_sl_spread_mult;

      //--- Use whichever gives wider values (protects against noise)
      m_tp_distance = MathMax(tp_atr, tp_spread);
      m_sl_distance = MathMax(sl_atr, sl_spread);

      //--- Smart TP: use distance to BB middle if larger
      if(m_smart_tp)
      {
         double bb_middle = bb.GetMiddle(ind, 1);
         if(bb_middle > 0)
         {
            double bb_dist = MathAbs(entry_price - bb_middle);
            if(bb_dist > m_tp_distance)
               m_tp_distance = bb_dist;
         }
      }

      //--- Apply floors and ceilings (convert points to price)
      double min_tp_price = m_min_tp_pts * point;
      double max_tp_price = m_max_tp_pts * point;
      double min_sl_price = m_min_sl_pts * point;
      double max_sl_price = m_max_sl_pts * point;

      m_tp_distance = MathMax(min_tp_price, MathMin(max_tp_price, m_tp_distance));
      m_sl_distance = MathMax(min_sl_price, MathMin(max_sl_price, m_sl_distance));

      //--- Min R:R enforcement
      if(m_sl_distance > 0 && (m_tp_distance / m_sl_distance) < m_min_rr)
         return false;  // Skip trade

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get TP/SL prices for a given direction                            |
   //+------------------------------------------------------------------+
   double GetTPPrice(double entry_price, int direction)
   {
      if(direction == DIR_BUY)
         return entry_price + m_tp_distance;
      else
         return entry_price - m_tp_distance;
   }

   double GetSLPrice(double entry_price, int direction)
   {
      if(direction == DIR_BUY)
         return entry_price - m_sl_distance;
      else
         return entry_price + m_sl_distance;
   }

   //--- Accessors
   double GetTPDistance()   { return m_tp_distance; }
   double GetSLDistance()   { return m_sl_distance; }
   double GetTPPoints(double point) { return (point > 0) ? m_tp_distance / point : 0; }
   double GetSLPoints(double point) { return (point > 0) ? m_sl_distance / point : 0; }
};

#endif
