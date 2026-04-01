//+------------------------------------------------------------------+
//| TwoPoleSignal.mqh                                                  |
//| Four-layer confluence entry engine for TwoPoleScalp               |
//| Layer 1: Two-Pole Oscillator crossover in OB/OS zone (primary)   |
//| Layer 2: EMA(200) M15 trend direction                             |
//| Layer 3: RSI recovery confirmation on M5                          |
//| Layer 4: Volume confirmation + ATR activity gate                  |
//+------------------------------------------------------------------+
#ifndef TWOPOLE_SIGNAL_MQH
#define TWOPOLE_SIGNAL_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/TwoPoleFilter.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/ATRVolatility.mqh"
#include "TrendFilter.mqh"

//+------------------------------------------------------------------+
//| CTwoPoleSignal                                                     |
//+------------------------------------------------------------------+
class CTwoPoleSignal
{
private:
   CTrendFilter    m_trend;
   CRSISignal      m_rsi;
   CATRVolatility  m_atr;

   //--- Volume settings
   double m_vol_mult;
   int    m_vol_window;

   //--- Last signal debug info
   string m_reject_reason;

public:
   CTwoPoleSignal() : m_vol_mult(1.2), m_vol_window(10) {}

   void Init(double rsi_deviation, int slope_bars, double chop_mult,
             double vol_mult, int vol_window, double min_atr)
   {
      m_rsi.Init(rsi_deviation, false);
      m_trend.Init(slope_bars, chop_mult);
      m_atr.Init(1.0, 1.5, min_atr);
      m_vol_mult       = vol_mult;
      m_vol_window     = vol_window;
      m_reject_reason  = "";
   }

   //+------------------------------------------------------------------+
   //| Check all 4 layers — returns DIR_BUY, DIR_SELL, or DIR_NONE     |
   //+------------------------------------------------------------------+
   int CheckSignal(CIndicatorManager &ind, CTwoPoleFilter &twopole,
                   string symbol, ENUM_TIMEFRAMES tf)
   {
      m_reject_reason = "";

      double mid_price = (SymbolInfoDouble(symbol, SYMBOL_ASK) +
                          SymbolInfoDouble(symbol, SYMBOL_BID)) / 2.0;

      //--- Layer 1: Two-Pole Oscillator signal (primary)
      int tp_signal = twopole.GetSignal();
      if(tp_signal == DIR_NONE)
      {
         m_reject_reason = "No Two-Pole crossover signal";
         return DIR_NONE;
      }

      //--- Layer 2: Trend Direction (EMA 200 on M15)
      double atr_short = ind.GetATRShort(1);
      int trend_dir = m_trend.GetDirection(ind, mid_price, atr_short);
      if(trend_dir == DIR_NONE)
      {
         m_reject_reason = "No clear trend (chop zone)";
         return DIR_NONE;
      }

      //--- Two-Pole must agree with trend
      if(tp_signal != trend_dir)
      {
         m_reject_reason = "Two-Pole signal conflicts with trend";
         return DIR_NONE;
      }

      //--- Layer 3: RSI Recovery Confirmation
      double rsi_curr = ind.GetRSI(1);
      double rsi_prev = ind.GetRSI(2);
      int rsi_signal = m_rsi.CheckRecovery(rsi_curr, rsi_prev);
      if(rsi_signal == DIR_NONE)
      {
         m_reject_reason = "No RSI recovery (curr=" + DoubleToString(rsi_curr, 1)
                          + " prev=" + DoubleToString(rsi_prev, 1) + ")";
         return DIR_NONE;
      }

      //--- RSI must agree with trend
      if(rsi_signal != trend_dir)
      {
         m_reject_reason = "RSI recovery conflicts with trend";
         return DIR_NONE;
      }

      //--- Layer 4: ATR Activity Gate + Volume
      if(!m_atr.IsMarketActive(ind))
      {
         m_reject_reason = "ATR below minimum (market dead)";
         return DIR_NONE;
      }

      if(!IsVolumeConfirmed(symbol, tf))
      {
         m_reject_reason = "Volume below threshold";
         return DIR_NONE;
      }

      //--- All 4 layers agree
      return trend_dir;
   }

   //+------------------------------------------------------------------+
   //| Volume confirmation                                               |
   //+------------------------------------------------------------------+
   bool IsVolumeConfirmed(string symbol, ENUM_TIMEFRAMES tf)
   {
      long vol_buf[];
      if(CopyTickVolume(symbol, tf, 1, m_vol_window + 1, vol_buf) < m_vol_window + 1)
         return true;

      long current_vol = vol_buf[m_vol_window];
      double avg = 0;
      for(int i = 0; i < m_vol_window; i++)
         avg += (double)vol_buf[i];
      avg /= m_vol_window;

      if(avg <= 0) return true;
      return ((double)current_vol >= avg * m_vol_mult);
   }

   //--- Debug accessors
   string       GetRejectReason()  { return m_reject_reason; }
   CTrendFilter *GetTrendFilter()  { return &m_trend; }
   CRSISignal   *GetRSI()         { return &m_rsi; }
};

#endif
