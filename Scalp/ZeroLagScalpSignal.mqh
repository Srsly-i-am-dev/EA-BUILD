//+------------------------------------------------------------------+
//| ZeroLagScalpSignal.mqh                                            |
//| Four-layer confluence entry engine for ZeroLagScalp               |
//| Layer 1: ZLEMA entry (close crosses ZLEMA within trend)           |
//| Layer 2: EMA(200) M15 trend direction                             |
//| Layer 3: RSI recovery confirmation on M5                          |
//| Layer 4: Volume confirmation + ATR activity gate                  |
//+------------------------------------------------------------------+
#ifndef ZEROLAG_SCALP_SIGNAL_MQH
#define ZEROLAG_SCALP_SIGNAL_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/ZeroLagEMA.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/ATRVolatility.mqh"
#include "TrendFilter.mqh"

//+------------------------------------------------------------------+
//| CZeroLagScalpSignal                                                |
//+------------------------------------------------------------------+
class CZeroLagScalpSignal
{
private:
   CTrendFilter    m_trend;
   CRSISignal      m_rsi;
   CATRVolatility  m_atr;

   double m_vol_mult;
   int    m_vol_window;
   string m_reject_reason;

public:
   CZeroLagScalpSignal() : m_vol_mult(1.2), m_vol_window(10) {}

   void Init(double rsi_deviation, int slope_bars, double chop_mult,
             double vol_mult, int vol_window, double min_atr)
   {
      m_rsi.Init(rsi_deviation, false);
      m_trend.Init(slope_bars, chop_mult);
      m_atr.Init(1.0, 1.5, min_atr);
      m_vol_mult      = vol_mult;
      m_vol_window    = vol_window;
      m_reject_reason = "";
   }

   //+------------------------------------------------------------------+
   //| Check all 4 layers                                                |
   //+------------------------------------------------------------------+
   int CheckSignal(CIndicatorManager &ind, CZeroLagEMA &zlema,
                   string symbol, ENUM_TIMEFRAMES tf)
   {
      m_reject_reason = "";

      double close_curr = iClose(symbol, tf, 1);
      double close_prev = iClose(symbol, tf, 2);
      double mid_price  = (SymbolInfoDouble(symbol, SYMBOL_ASK) +
                           SymbolInfoDouble(symbol, SYMBOL_BID)) / 2.0;

      if(close_curr == 0 || close_prev == 0)
      {
         m_reject_reason = "No price data";
         return DIR_NONE;
      }

      //--- Layer 1: ZLEMA Entry Signal
      // Bullish: close crosses above ZLEMA, within established uptrend
      // Bearish: close crosses below ZLEMA, within established downtrend
      int zlema_dir = zlema.GetDirection();
      double zlema_val = zlema.GetValue();

      if(zlema_dir == DIR_NONE)
      {
         m_reject_reason = "No ZLEMA trend established";
         return DIR_NONE;
      }

      int entry_signal = DIR_NONE;

      // Bullish entry: close crosses above ZLEMA in uptrend
      if(close_prev <= zlema_val && close_curr > zlema_val && zlema_dir == DIR_BUY)
         entry_signal = DIR_BUY;
      // Bearish entry: close crosses below ZLEMA in downtrend
      else if(close_prev >= zlema_val && close_curr < zlema_val && zlema_dir == DIR_SELL)
         entry_signal = DIR_SELL;

      if(entry_signal == DIR_NONE)
      {
         m_reject_reason = "No ZLEMA crossover entry";
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

      if(entry_signal != trend_dir)
      {
         m_reject_reason = "ZLEMA entry conflicts with EMA trend";
         return DIR_NONE;
      }

      //--- Layer 3: RSI Recovery Confirmation
      double rsi_curr = ind.GetRSI(1);
      double rsi_prev = ind.GetRSI(2);
      int rsi_signal = m_rsi.CheckRecovery(rsi_curr, rsi_prev);

      if(rsi_signal == DIR_NONE)
      {
         m_reject_reason = "No RSI recovery";
         return DIR_NONE;
      }

      if(rsi_signal != trend_dir)
      {
         m_reject_reason = "RSI recovery conflicts with trend";
         return DIR_NONE;
      }

      //--- Layer 4: ATR + Volume
      if(!m_atr.IsMarketActive(ind))
      {
         m_reject_reason = "ATR below minimum";
         return DIR_NONE;
      }

      if(!IsVolumeConfirmed(symbol, tf))
      {
         m_reject_reason = "Volume below threshold";
         return DIR_NONE;
      }

      return trend_dir;
   }

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

   string       GetRejectReason()  { return m_reject_reason; }
   CTrendFilter *GetTrendFilter()  { return &m_trend; }
};

#endif
