//+------------------------------------------------------------------+
//| BBEngine.mqh                                                      |
//| BB touch + multi-indicator confluence signal engine for GoldBB    |
//+------------------------------------------------------------------+
#ifndef BB_ENGINE_MQH
#define BB_ENGINE_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/BollingerCalc.mqh"
#include "../Indicators/SuperTrend.mqh"
#include "../Indicators/ZeroLagEMA.mqh"
#include "../Indicators/VWAPCalc.mqh"
#include "../Indicators/KeltnerChannel.mqh"
#include "../Indicators/StdDevRegime.mqh"
#include "../Indicators/FibLevels.mqh"
#include "SignalScorer.mqh"
#include "TFPresets.mqh"

//+------------------------------------------------------------------+
//| CBBEngine                                                         |
//+------------------------------------------------------------------+
class CBBEngine
{
private:
   //--- Indicators (owned by engine)
   CIndicatorManager  m_ind;
   CSuperTrend        m_supertrend;
   CZeroLagEMA        m_zlema;
   CVWAPCalc          m_vwap;
   CKeltnerChannel    m_keltner;
   CStdDevRegime      m_stddev;
   CFibLevels         m_fib;
   CRSISignal         m_rsi;
   CBollingerCalc     m_bb;

   //--- Scoring
   CSignalScorer      m_scorer;

   //--- Settings
   TFPreset           m_preset;
   string             m_symbol;
   bool               m_close_back_inside;
   double             m_touch_buffer;
   double             m_vol_mult;
   int                m_vol_window;
   double             m_atr_min_gate;

   //--- Enable flags
   bool               m_use_keltner;
   bool               m_use_zlema;
   bool               m_use_vwap;
   bool               m_use_stddev;
   bool               m_use_rsi;
   bool               m_use_volume;

   //--- Debug
   string             m_reject_reason;
   SignalScore        m_last_score;

   //+------------------------------------------------------------------+
   //| Volume confirmation                                               |
   //+------------------------------------------------------------------+
   bool IsVolumeOK(ENUM_TIMEFRAMES tf, int shift = 1)
   {
      if(!m_use_volume) return true;

      long vol_buf[];
      if(CopyTickVolume(m_symbol, tf, shift, m_vol_window + 1, vol_buf) < m_vol_window + 1)
         return true;

      long current_vol = vol_buf[m_vol_window];
      double avg = 0;
      for(int i = 0; i < m_vol_window; i++)
         avg += (double)vol_buf[i];
      avg /= m_vol_window;

      if(avg <= 0) return true;
      return ((double)current_vol >= avg * m_vol_mult);
   }

public:
   CBBEngine() : m_close_back_inside(true), m_touch_buffer(10.0),
                 m_vol_mult(1.2), m_vol_window(10), m_atr_min_gate(0.30),
                 m_use_keltner(true), m_use_zlema(true), m_use_vwap(true),
                 m_use_stddev(true), m_use_rsi(true), m_use_volume(true) {}

   //+------------------------------------------------------------------+
   //| Initialize all indicators using TF preset + overrides             |
   //+------------------------------------------------------------------+
   bool Init(string symbol, ENUM_GOLD_TF tf_selection,
             bool close_back_inside, double touch_buffer,
             bool use_kc, bool use_zl, bool use_vwap, bool use_sd,
             bool use_rsi, bool use_vol,
             // Override params (0 = use preset)
             int bb_period, double bb_dev,
             int st_atr, double st_mult,
             int kc_ema, int kc_atr, double kc_mult,
             int zl_len, double zl_band,
             double vwap_slope,
             int sd_period, int sd_sma,
             int rsi_period, double rsi_dev,
             double vol_mult, int vol_window,
             int atr_period, double atr_min)
   {
      m_symbol = symbol;
      m_preset = GetTFPreset(tf_selection);

      //--- Apply overrides (0 = use preset default)
      int p_bb     = (bb_period > 0)  ? bb_period  : m_preset.bb_period;
      double p_bbd = (bb_dev > 0)     ? bb_dev     : m_preset.bb_deviation;
      int p_st_a   = (st_atr > 0)     ? st_atr     : m_preset.st_atr_period;
      double p_st_m= (st_mult > 0)    ? st_mult    : m_preset.st_multiplier;
      int p_kc_e   = (kc_ema > 0)     ? kc_ema     : m_preset.kc_ema_period;
      int p_kc_a   = (kc_atr > 0)     ? kc_atr     : m_preset.kc_atr_period;
      double p_kc_m= (kc_mult > 0)    ? kc_mult    : m_preset.kc_multiplier;
      int p_zl     = (zl_len > 0)     ? zl_len     : m_preset.zlema_length;
      double p_zlb = (zl_band > 0)    ? zl_band    : m_preset.zlema_band_mult;
      double p_vws = (vwap_slope > 0) ? vwap_slope : m_preset.vwap_min_slope;
      int p_sd_p   = (sd_period > 0)  ? sd_period  : m_preset.stddev_period;
      int p_sd_s   = (sd_sma > 0)     ? sd_sma     : m_preset.stddev_sma_period;
      int p_rsi    = (rsi_period > 0) ? rsi_period : m_preset.rsi_period;
      double p_rsid= (rsi_dev > 0)    ? rsi_dev    : m_preset.rsi_deviation;
      double p_vm  = (vol_mult > 0)   ? vol_mult   : m_preset.vol_mult;
      int p_vw     = (vol_window > 0) ? vol_window : m_preset.vol_window;
      int p_atr    = (atr_period > 0) ? atr_period : m_preset.atr_period;
      double p_am  = (atr_min > 0)    ? atr_min    : m_preset.atr_min_gate;

      m_close_back_inside = close_back_inside;
      m_touch_buffer      = touch_buffer;
      m_vol_mult          = p_vm;
      m_vol_window        = p_vw;
      m_atr_min_gate      = p_am;
      m_use_keltner       = use_kc;
      m_use_zlema         = use_zl;
      m_use_vwap          = use_vwap;
      m_use_stddev        = use_sd;
      m_use_rsi           = use_rsi;
      m_use_volume        = use_vol;

      ENUM_TIMEFRAMES tf = m_preset.tf;

      //--- Core indicators via IndicatorManager (RSI, ATR, MA for BB, StdDev for BB)
      if(!m_ind.Init(symbol, p_rsi, tf, p_atr, tf, p_atr * 4, tf,
                     p_bb, tf, p_bb + 1, tf))
         return false;

      //--- BB calculator
      m_bb.Init(p_bbd);

      //--- RSI signal
      m_rsi.Init(p_rsid, false);

      //--- SuperTrend
      if(!m_supertrend.Init(symbol, tf, p_st_a, p_st_m)) return false;
      m_supertrend.Warmup(200);

      //--- Keltner Channel
      if(m_use_keltner)
      {
         if(!m_keltner.Init(symbol, tf, p_kc_e, p_kc_a, p_kc_m)) return false;
      }

      //--- Zero-Lag EMA
      if(m_use_zlema)
      {
         if(!m_zlema.Init(symbol, tf, p_zl, p_zlb)) return false;
         m_zlema.Warmup(p_zl * 2);
      }

      //--- VWAP
      if(m_use_vwap)
      {
         m_vwap.Init(symbol, tf);
         m_vwap.Recalculate();
      }

      //--- StdDev Regime
      if(m_use_stddev)
      {
         if(!m_stddev.Init(symbol, tf, p_sd_p, p_sd_s)) return false;
      }

      //--- Fib Levels
      m_fib.Init(m_preset.fib_lookback, m_preset.fib_skip);

      //--- Scorer
      m_scorer.InitBB();

      return true;
   }

   void Deinit()
   {
      m_ind.Deinit();
      m_supertrend.Deinit();
      if(m_use_keltner) m_keltner.Deinit();
      if(m_use_zlema)   m_zlema.Deinit();
      if(m_use_stddev)  m_stddev.Deinit();
   }

   //+------------------------------------------------------------------+
   //| Check all confluence layers and return scored signal               |
   //+------------------------------------------------------------------+
   SignalScore CheckSignal()
   {
      m_reject_reason = "";
      ENUM_TIMEFRAMES tf = m_preset.tf;

      //--- Update tick-sensitive indicators
      m_supertrend.Update(1);
      if(m_use_zlema) m_zlema.Update(1);
      if(m_use_vwap)  m_vwap.Calculate(1);

      //--- Get price data
      double close_curr = iClose(m_symbol, tf, 1);
      double close_prev = iClose(m_symbol, tf, 2);
      double high_curr  = iHigh(m_symbol, tf, 1);
      double low_curr   = iLow(m_symbol, tf, 1);
      double mid_price  = (SymbolInfoDouble(m_symbol, SYMBOL_ASK) +
                           SymbolInfoDouble(m_symbol, SYMBOL_BID)) / 2.0;
      double point      = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(close_curr == 0 || close_prev == 0)
      {
         m_reject_reason = "No price data";
         SignalScore empty;
         ZeroMemory(empty);
         return empty;
      }

      //--- PRIMARY: BB touch or close-back-inside
      int bb_dir = DIR_NONE;
      if(m_close_back_inside)
      {
         bb_dir = m_bb.CheckCloseBackInside(m_ind, close_curr, close_prev);
      }
      else
      {
         //--- Touch mode: check if high/low touches BB within buffer
         double upper = m_bb.GetUpper(m_ind, 1);
         double lower = m_bb.GetLower(m_ind, 1);
         double buf_price = m_touch_buffer * point;

         if(upper > 0 && high_curr >= upper - buf_price)
            bb_dir = DIR_SELL;
         else if(lower > 0 && low_curr <= lower + buf_price)
            bb_dir = DIR_BUY;
      }

      bool primary_ok = (bb_dir != DIR_NONE);

      //--- ATR minimum gate
      double atr_val = m_ind.GetATRShort(1);
      if(atr_val < m_atr_min_gate)
      {
         m_reject_reason = "ATR below minimum";
         SignalScore empty;
         ZeroMemory(empty);
         return empty;
      }

      //--- SuperTrend direction
      bool st_ok = (m_supertrend.GetDirection() == bb_dir);

      //--- Keltner squeeze (NOT in squeeze = good)
      bool kc_ok = true;
      if(m_use_keltner && primary_ok)
      {
         double bb_upper = m_bb.GetUpper(m_ind, 1);
         double bb_lower = m_bb.GetLower(m_ind, 1);
         kc_ok = !m_keltner.IsBBSqueeze(bb_upper, bb_lower, 1);
      }

      //--- StdDev regime
      bool sd_ok = true;
      if(m_use_stddev)
         sd_ok = m_stddev.IsMeanReversionSafe(1);

      //--- Zero-Lag EMA
      bool zl_ok = true;
      if(m_use_zlema)
         zl_ok = (m_zlema.GetDirection() == bb_dir);

      //--- VWAP bias
      bool vw_ok = true;
      if(m_use_vwap && m_vwap.IsValid())
      {
         int vwap_bias = m_vwap.GetBias(mid_price);
         vw_ok = (vwap_bias == bb_dir);
      }

      //--- RSI recovery
      bool rsi_ok = true;
      if(m_use_rsi)
      {
         double rsi_curr = m_ind.GetRSI(1);
         double rsi_prev = m_ind.GetRSI(2);
         int rsi_sig = m_rsi.CheckRecovery(rsi_curr, rsi_prev);
         rsi_ok = (rsi_sig == bb_dir);
      }

      //--- Volume
      bool vol_ok = IsVolumeOK(tf, 1);

      //--- Calculate score
      m_last_score = m_scorer.Calculate(bb_dir,
                        primary_ok, st_ok, zl_ok, vw_ok, sd_ok, rsi_ok, vol_ok, kc_ok);

      if(m_last_score.direction == DIR_NONE && primary_ok)
         m_reject_reason = "Score below threshold: " + m_last_score.ToString();

      return m_last_score;
   }

   //--- Update Fib levels (call before TP/SL calculation)
   bool UpdateFib() { return m_fib.Calculate(m_symbol, m_preset.tf); }

   //--- Accessors
   CIndicatorManager *GetIndicators()  { return &m_ind; }
   CBollingerCalc    *GetBB()          { return &m_bb; }
   CSuperTrend       *GetSuperTrend()  { return &m_supertrend; }
   CFibLevels        *GetFib()         { return &m_fib; }
   CVWAPCalc         *GetVWAP()        { return &m_vwap; }
   CStdDevRegime     *GetStdDev()      { return &m_stddev; }
   CZeroLagEMA       *GetZLEMA()       { return &m_zlema; }
   void               GetPreset(TFPreset &out) { out = m_preset; }
   ENUM_TIMEFRAMES    GetPresetTF()     { return m_preset.tf; }
   string             GetRejectReason() { return m_reject_reason; }
   SignalScore        GetLastScore()    { return m_last_score; }

   void SetScoreThreshold(int t) { m_scorer.SetThreshold(t); }
};

#endif
