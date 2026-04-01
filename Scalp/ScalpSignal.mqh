//+------------------------------------------------------------------+
//| ScalpSignal.mqh                                                   |
//| Four-layer confluence entry engine for WakaScalp                  |
//| Layer 1: EMA(200) M15 trend direction                            |
//| Layer 2: BB close-back-inside on M5                              |
//| Layer 3: RSI recovery confirmation on M5                          |
//| Layer 4: Volume confirmation + ATR activity gate                  |
//+------------------------------------------------------------------+
#ifndef SCALP_SIGNAL_MQH
#define SCALP_SIGNAL_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/BollingerCalc.mqh"
#include "../Indicators/ATRVolatility.mqh"
#include "TrendFilter.mqh"

//+------------------------------------------------------------------+
//| CScalpSignal                                                      |
//+------------------------------------------------------------------+
class CScalpSignal
{
private:
   CTrendFilter    m_trend;
   CRSISignal      m_rsi;
   CBollingerCalc  m_bb;
   CATRVolatility  m_atr;

   //--- Volume settings
   double m_vol_mult;       // Volume multiplier threshold (e.g., 1.2)
   int    m_vol_window;     // Volume averaging window (bars)
   double m_squeeze_thresh; // BB squeeze threshold (% of ATR)

   //--- Last signal debug info
   string m_reject_reason;

public:
   CScalpSignal() : m_vol_mult(1.2), m_vol_window(10), m_squeeze_thresh(0.5) {}

   void Init(double rsi_deviation, double bb_deviation,
             int slope_bars, double chop_mult,
             double vol_mult, int vol_window,
             double min_atr, double squeeze_thresh)
   {
      m_rsi.Init(rsi_deviation, false);
      m_bb.Init(bb_deviation);
      m_trend.Init(slope_bars, chop_mult);
      m_atr.Init(1.0, 1.5, min_atr);
      m_vol_mult       = vol_mult;
      m_vol_window     = vol_window;
      m_squeeze_thresh = squeeze_thresh;
      m_reject_reason  = "";
   }

   //+------------------------------------------------------------------+
   //| Check all 4 layers — returns DIR_BUY, DIR_SELL, or DIR_NONE     |
   //+------------------------------------------------------------------+
   int CheckSignal(CIndicatorManager &ind, string symbol, ENUM_TIMEFRAMES tf)
   {
      m_reject_reason = "";

      //--- Get price data (completed bars)
      double close_curr = iClose(symbol, tf, 1);
      double close_prev = iClose(symbol, tf, 2);
      double mid_price  = (SymbolInfoDouble(symbol, SYMBOL_ASK) +
                           SymbolInfoDouble(symbol, SYMBOL_BID)) / 2.0;

      if(close_curr == 0 || close_prev == 0)
      {
         m_reject_reason = "No price data";
         return DIR_NONE;
      }

      //--- Layer 1: Trend Direction (EMA 200 on M15)
      double atr_short = ind.GetATRShort(1);
      int trend_dir = m_trend.GetDirection(ind, mid_price, atr_short);
      if(trend_dir == DIR_NONE)
      {
         m_reject_reason = "No clear trend (chop zone)";
         return DIR_NONE;
      }

      //--- Layer 2: BB Close-Back-Inside
      int bb_signal = m_bb.CheckCloseBackInside(ind, close_curr, close_prev);
      if(bb_signal == DIR_NONE)
      {
         m_reject_reason = "No BB close-back-inside";
         return DIR_NONE;
      }

      //--- BB must agree with trend
      if(bb_signal != trend_dir)
      {
         m_reject_reason = "BB signal conflicts with trend";
         return DIR_NONE;
      }

      //--- BB squeeze check (breakout imminent — skip mean-reversion)
      double atr_long = ind.GetATRLong(1);
      if(m_bb.IsSqueezed(ind, atr_long, m_squeeze_thresh))
      {
         m_reject_reason = "BB squeeze detected";
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

      //--- Layer 4: Volume Confirmation + ATR Activity Gate
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
   //| Volume confirmation: current bar volume > mult * average          |
   //+------------------------------------------------------------------+
   bool IsVolumeConfirmed(string symbol, ENUM_TIMEFRAMES tf)
   {
      long vol_buf[];
      if(CopyTickVolume(symbol, tf, 1, m_vol_window + 1, vol_buf) < m_vol_window + 1)
         return true;  // If can't read volume, don't block

      //--- Current bar is at index m_vol_window (last element)
      long current_vol = vol_buf[m_vol_window];

      //--- Average of previous bars
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
   CBollingerCalc *GetBB()        { return &m_bb; }
};

#endif
