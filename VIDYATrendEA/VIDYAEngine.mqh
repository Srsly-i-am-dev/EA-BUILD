//+------------------------------------------------------------------+
//| VIDYAEngine.mqh                                                   |
//| Scored confluence signal engine for VIDYATrend EA                 |
//| Primary: VIDYA trend flip                                         |
//| Confluence: SuperTrend, ZLEMA, RSI, Volume, ATR                  |
//+------------------------------------------------------------------+
#ifndef VIDYA_ENGINE_MQH
#define VIDYA_ENGINE_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/VIDYACalc.mqh"
#include "../Indicators/SuperTrend.mqh"
#include "../Indicators/ZeroLagEMA.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/ATRVolatility.mqh"

//+------------------------------------------------------------------+
//| CVIDYAEngine                                                       |
//+------------------------------------------------------------------+
class CVIDYAEngine
{
private:
   //--- Confluence indicators (owned)
   CSuperTrend     m_supertrend;
   CZeroLagEMA     m_zlema;
   CRSISignal      m_rsi;
   CATRVolatility  m_atr;

   //--- Scoring weights
   int    m_w_primary;       // VIDYA trend flip (mandatory)
   int    m_w_supertrend;    // SuperTrend agreement
   int    m_w_zlema;         // ZLEMA agreement
   int    m_w_rsi;           // RSI not extreme opposite
   int    m_w_volume;        // Volume above average
   int    m_w_atr;           // ATR above gate
   int    m_threshold;       // Min score to trade

   //--- Volume settings
   double m_vol_mult;
   int    m_vol_window;

   //--- State
   string m_reject_reason;
   int    m_last_score;
   bool   m_initialized;

public:
   CVIDYAEngine() : m_w_primary(30), m_w_supertrend(20), m_w_zlema(15),
                    m_w_rsi(15), m_w_volume(10), m_w_atr(10),
                    m_threshold(65), m_vol_mult(1.2), m_vol_window(10),
                    m_last_score(0), m_initialized(false) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int score_threshold = 65)
   {
      m_threshold = score_threshold;

      //--- Initialize SuperTrend (ATR(10), mult 3.0)
      if(!m_supertrend.Init(symbol, tf, 10, 3.0))
         return false;

      //--- Initialize ZLEMA (length 70, band 1.2)
      if(!m_zlema.Init(symbol, tf, 70, 1.2))
         return false;

      m_rsi.Init(20.0, false);  // RSI deviation 20 from 50
      m_atr.Init(1.0, 1.5, 0.30);

      m_initialized = true;
      return true;
   }

   void Warmup(int bars = 500)
   {
      m_supertrend.Warmup(bars);
      m_zlema.Warmup(bars);
   }

   void Deinit()
   {
      m_supertrend.Deinit();
      m_zlema.Deinit();
   }

   //+------------------------------------------------------------------+
   //| Update confluence indicators on new bar                           |
   //+------------------------------------------------------------------+
   void Update(int shift = 1)
   {
      m_supertrend.Update(shift);
      m_zlema.Update(shift);
   }

   //+------------------------------------------------------------------+
   //| Check signal with scored confluence                                |
   //+------------------------------------------------------------------+
   int CheckSignal(CIndicatorManager &ind, CVIDYACalc &vidya,
                   string symbol, ENUM_TIMEFRAMES tf)
   {
      m_reject_reason = "";
      m_last_score = 0;

      //--- Primary: VIDYA trend flip (mandatory)
      int vidya_signal = vidya.GetSignal();
      if(vidya_signal == DIR_NONE)
      {
         m_reject_reason = "No VIDYA trend flip";
         return DIR_NONE;
      }

      int score = m_w_primary;  // Primary always counts

      //--- SuperTrend agreement
      if(m_supertrend.GetDirection() == vidya_signal)
         score += m_w_supertrend;

      //--- ZLEMA agreement
      if(m_zlema.GetDirection() == vidya_signal)
         score += m_w_zlema;

      //--- RSI: not extreme opposite
      double rsi_curr = ind.GetRSI(1);
      double rsi_prev = ind.GetRSI(2);
      int rsi_signal = m_rsi.CheckRecovery(rsi_curr, rsi_prev);
      if(rsi_signal == vidya_signal || rsi_signal == DIR_NONE)
         score += m_w_rsi;
      // If RSI disagrees, don't add points (but don't block)

      //--- Volume
      if(IsVolumeOK(symbol, tf))
         score += m_w_volume;

      //--- ATR activity
      if(m_atr.IsMarketActive(ind))
         score += m_w_atr;

      m_last_score = score;

      if(score < m_threshold)
      {
         m_reject_reason = "Score " + IntegerToString(score) + " < threshold " + IntegerToString(m_threshold);
         return DIR_NONE;
      }

      return vidya_signal;
   }

   //+------------------------------------------------------------------+
   bool IsVolumeOK(string symbol, ENUM_TIMEFRAMES tf)
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

   //--- Accessors
   string GetRejectReason() { return m_reject_reason; }
   int    GetLastScore()    { return m_last_score; }
   double GetLotFactor()
   {
      if(m_last_score >= 85) return 1.00;
      if(m_last_score >= 75) return 0.75;
      if(m_last_score >= 65) return 0.50;
      return 0.0;
   }
};

#endif
