//+------------------------------------------------------------------+
//| PatternEngine.mqh                                                 |
//| Pattern recognition + multi-indicator confluence for GoldPattern  |
//+------------------------------------------------------------------+
#ifndef PATTERN_ENGINE_MQH
#define PATTERN_ENGINE_MQH

#include "../Core/Defines.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/PatternMatcher.mqh"
#include "../Indicators/SuperTrend.mqh"
#include "../Indicators/ZeroLagEMA.mqh"
#include "../Indicators/VWAPCalc.mqh"
#include "../Indicators/StdDevRegime.mqh"
#include "../Indicators/FibLevels.mqh"
#include "SignalScorer.mqh"
#include "TFPresets.mqh"

//+------------------------------------------------------------------+
//| CPatternEngine                                                    |
//+------------------------------------------------------------------+
class CPatternEngine
{
private:
   //--- Core indicators
   CIndicatorManager  m_ind;
   CPatternMatcher    m_pattern;
   CSuperTrend        m_supertrend;
   CZeroLagEMA        m_zlema;
   CVWAPCalc          m_vwap;
   CStdDevRegime      m_stddev;
   CFibLevels         m_fib;
   CRSISignal         m_rsi;

   //--- Scoring
   CSignalScorer      m_scorer;

   //--- Settings
   TFPreset           m_preset;
   string             m_symbol;
   int                m_min_matches;
   double             m_min_accuracy;
   double             m_vol_mult;
   int                m_vol_window;
   double             m_atr_min_gate;

   //--- Enable flags
   bool               m_use_supertrend;
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
   CPatternEngine() : m_min_matches(10), m_min_accuracy(60.0),
                      m_vol_mult(1.2), m_vol_window(10), m_atr_min_gate(0.30),
                      m_use_supertrend(true), m_use_zlema(true), m_use_vwap(true),
                      m_use_stddev(true), m_use_rsi(true), m_use_volume(true) {}

   //+------------------------------------------------------------------+
   //| Initialize all indicators                                         |
   //+------------------------------------------------------------------+
   bool Init(string symbol, ENUM_GOLD_TF tf_selection,
             bool use_st, bool use_zl, bool use_vwap_f, bool use_sd,
             bool use_rsi_f, bool use_vol,
             // Pattern params (0 = use preset)
             int pattern_candles, double similarity, int min_matches,
             double min_accuracy, int lookback, int future_bars,
             bool use_wicks, int max_matches,
             // Indicator params (0 = use preset)
             int st_atr, double st_mult,
             int zl_len, double zl_band,
             double vwap_slope,
             int sd_period, int sd_sma,
             int rsi_period, double rsi_dev,
             double vol_mult, int vol_window,
             int atr_period, double atr_min)
   {
      m_symbol = symbol;
      m_preset = GetTFPreset(tf_selection);
      ENUM_TIMEFRAMES tf = m_preset.tf;

      //--- Apply overrides
      int p_pc     = (pattern_candles > 0) ? pattern_candles : m_preset.pattern_candles;
      double p_sim = (similarity > 0)      ? similarity     : m_preset.similarity_threshold;
      m_min_matches  = (min_matches > 0)   ? min_matches    : m_preset.min_matches;
      m_min_accuracy = (min_accuracy > 0)  ? min_accuracy   : m_preset.min_accuracy;
      int p_lb     = (lookback > 0)        ? lookback       : m_preset.lookback_bars;
      int p_fb     = (future_bars > 0)     ? future_bars    : m_preset.future_bars;
      int p_st_a   = (st_atr > 0)         ? st_atr         : m_preset.st_atr_period;
      double p_st_m= (st_mult > 0)        ? st_mult        : m_preset.st_multiplier;
      int p_zl     = (zl_len > 0)         ? zl_len         : m_preset.zlema_length;
      double p_zlb = (zl_band > 0)        ? zl_band        : m_preset.zlema_band_mult;
      double p_vws = (vwap_slope > 0)     ? vwap_slope     : m_preset.vwap_min_slope;
      int p_sd_p   = (sd_period > 0)      ? sd_period      : m_preset.stddev_period;
      int p_sd_s   = (sd_sma > 0)         ? sd_sma         : m_preset.stddev_sma_period;
      int p_rsi    = (rsi_period > 0)     ? rsi_period     : m_preset.rsi_period;
      double p_rsid= (rsi_dev > 0)        ? rsi_dev        : m_preset.rsi_deviation;
      int p_atr    = (atr_period > 0)     ? atr_period     : m_preset.atr_period;
      m_vol_mult   = (vol_mult > 0)       ? vol_mult       : m_preset.vol_mult;
      m_vol_window = (vol_window > 0)     ? vol_window     : m_preset.vol_window;
      m_atr_min_gate = (atr_min > 0)     ? atr_min        : m_preset.atr_min_gate;

      m_use_supertrend = use_st;
      m_use_zlema      = use_zl;
      m_use_vwap       = use_vwap_f;
      m_use_stddev     = use_sd;
      m_use_rsi        = use_rsi_f;
      m_use_volume     = use_vol;

      //--- Pattern matcher
      m_pattern.Init(p_lb, p_fb, p_sim, use_wicks);
      m_pattern.SetPatternLength(p_pc);
      m_pattern.SetMaxMatches(max_matches);

      //--- Core indicators (RSI, ATR short, ATR long, MA, StdDev)
      if(!m_ind.Init(symbol, p_rsi, tf, p_atr, tf, p_atr * 4, tf,
                     20, tf, 21, tf))
         return false;

      //--- RSI signal
      m_rsi.Init(p_rsid, false);

      //--- SuperTrend
      if(m_use_supertrend)
      {
         if(!m_supertrend.Init(symbol, tf, p_st_a, p_st_m)) return false;
         m_supertrend.Warmup(200);
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

      //--- Fib
      m_fib.Init(m_preset.fib_lookback, m_preset.fib_skip);

      //--- Scorer
      m_scorer.InitPattern();

      return true;
   }

   void Deinit()
   {
      m_ind.Deinit();
      if(m_use_supertrend) m_supertrend.Deinit();
      if(m_use_zlema)      m_zlema.Deinit();
      if(m_use_stddev)     m_stddev.Deinit();
   }

   //+------------------------------------------------------------------+
   //| Check pattern + confluence → return scored signal                 |
   //+------------------------------------------------------------------+
   SignalScore CheckSignal()
   {
      m_reject_reason = "";
      ENUM_TIMEFRAMES tf = m_preset.tf;

      //--- Update indicators
      if(m_use_supertrend) m_supertrend.Update(1);
      if(m_use_zlema)      m_zlema.Update(1);
      if(m_use_vwap)       m_vwap.Calculate(1);

      double mid_price = (SymbolInfoDouble(m_symbol, SYMBOL_ASK) +
                          SymbolInfoDouble(m_symbol, SYMBOL_BID)) / 2.0;

      //--- ATR minimum gate
      double atr_val = m_ind.GetATRShort(1);
      if(atr_val < m_atr_min_gate)
      {
         m_reject_reason = "ATR below minimum";
         SignalScore empty;
         ZeroMemory(empty);
         return empty;
      }

      //--- PRIMARY: Pattern match scan
      if(!m_pattern.ScanForBias(m_symbol, tf))
      {
         m_reject_reason = "Pattern scan failed";
         SignalScore empty;
         ZeroMemory(empty);
         return empty;
      }

      int pattern_dir = m_pattern.GetBias();
      int total_matches = m_pattern.GetTotalMatches();
      double confidence = m_pattern.GetConfidence();

      bool primary_ok = (pattern_dir != DIR_NONE &&
                         total_matches >= m_min_matches &&
                         confidence >= m_min_accuracy);

      if(!primary_ok)
      {
         m_reject_reason = "Pattern: dir=" + IntegerToString(pattern_dir)
                          + " matches=" + IntegerToString(total_matches)
                          + " conf=" + DoubleToString(confidence, 1) + "%";
      }

      //--- SuperTrend
      bool st_ok = true;
      if(m_use_supertrend)
         st_ok = (m_supertrend.GetDirection() == pattern_dir);

      //--- Zero-Lag EMA
      bool zl_ok = true;
      if(m_use_zlema)
         zl_ok = (m_zlema.GetDirection() == pattern_dir);

      //--- VWAP bias
      bool vw_ok = true;
      if(m_use_vwap && m_vwap.IsValid())
         vw_ok = (m_vwap.GetBias(mid_price) == pattern_dir);

      //--- StdDev regime
      bool sd_ok = true;
      if(m_use_stddev)
         sd_ok = m_stddev.IsMeanReversionSafe(1);

      //--- RSI confirmation
      bool rsi_ok = true;
      if(m_use_rsi)
      {
         double rsi_curr = m_ind.GetRSI(1);
         double rsi_prev = m_ind.GetRSI(2);
         int rsi_sig = m_rsi.CheckRecovery(rsi_curr, rsi_prev);
         //--- For pattern EA, RSI just needs to lean in the right direction
         //--- Not requiring full recovery — just not extreme in wrong direction
         if(rsi_sig != DIR_NONE)
            rsi_ok = (rsi_sig == pattern_dir);
         else
         {
            //--- RSI not at extremes — check if leaning correct direction
            if(pattern_dir == DIR_BUY)
               rsi_ok = (rsi_curr > rsi_prev);  // RSI rising
            else
               rsi_ok = (rsi_curr < rsi_prev);  // RSI falling
         }
      }

      //--- Volume
      bool vol_ok = IsVolumeOK(tf, 1);

      //--- Calculate score
      m_last_score = m_scorer.Calculate(pattern_dir,
                        primary_ok, st_ok, zl_ok, vw_ok, sd_ok, rsi_ok, vol_ok, true);

      if(m_last_score.direction == DIR_NONE && primary_ok)
         m_reject_reason = "Score below threshold: " + m_last_score.ToString();

      return m_last_score;
   }

   //--- Update Fib levels
   bool UpdateFib() { return m_fib.Calculate(m_symbol, m_preset.tf); }

   //--- Accessors
   CIndicatorManager *GetIndicators()  { return &m_ind; }
   CPatternMatcher   *GetPattern()     { return &m_pattern; }
   CSuperTrend       *GetSuperTrend()  { return &m_supertrend; }
   CFibLevels        *GetFib()         { return &m_fib; }
   CVWAPCalc         *GetVWAP()        { return &m_vwap; }
   void               GetPreset(TFPreset &out) { out = m_preset; }
   ENUM_TIMEFRAMES    GetPresetTF()     { return m_preset.tf; }
   string             GetRejectReason() { return m_reject_reason; }
   SignalScore        GetLastScore()    { return m_last_score; }

   void SetScoreThreshold(int t) { m_scorer.SetThreshold(t); }
};

#endif
