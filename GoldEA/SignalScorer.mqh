//+------------------------------------------------------------------+
//| SignalScorer.mqh                                                   |
//| Weighted scoring system for multi-indicator confluence             |
//| Score determines trade quality → affects lot sizing               |
//+------------------------------------------------------------------+
#ifndef SIGNAL_SCORER_MQH
#define SIGNAL_SCORER_MQH

//+------------------------------------------------------------------+
//| Signal component scores                                           |
//+------------------------------------------------------------------+
struct SignalScore
{
   int    total_score;
   int    direction;        // DIR_BUY, DIR_SELL, DIR_NONE
   bool   primary_valid;    // Mandatory signal passed?

   //--- Individual components (for panel/debug)
   bool   primary;          // BB touch or Pattern match
   bool   supertrend;
   bool   zlema;
   bool   vwap;
   bool   stddev;
   bool   rsi;
   bool   volume;
   bool   keltner;          // NOT in squeeze (for BB EA)

   //--- Lot multiplier based on score
   double GetLotFactor()
   {
      if(total_score >= 85) return 1.00;
      if(total_score >= 75) return 0.75;
      if(total_score >= 65) return 0.50;
      return 0.0;  // Below threshold — no trade
   }

   string ToString()
   {
      return "Score=" + IntegerToString(total_score)
           + " Dir=" + IntegerToString(direction)
           + " LotF=" + DoubleToString(GetLotFactor(), 2)
           + " [ST=" + (supertrend ? "Y" : "N")
           + " ZL=" + (zlema ? "Y" : "N")
           + " VW=" + (vwap ? "Y" : "N")
           + " SD=" + (stddev ? "Y" : "N")
           + " RS=" + (rsi ? "Y" : "N")
           + " VL=" + (volume ? "Y" : "N")
           + " KC=" + (keltner ? "Y" : "N") + "]";
   }
};

//+------------------------------------------------------------------+
//| CSignalScorer                                                     |
//+------------------------------------------------------------------+
class CSignalScorer
{
private:
   //--- Configurable weights
   int m_w_primary;
   int m_w_supertrend;
   int m_w_zlema;
   int m_w_vwap;
   int m_w_stddev;
   int m_w_rsi;
   int m_w_volume;
   int m_w_keltner;

   int m_threshold;    // Minimum score to trade

public:
   CSignalScorer() : m_w_primary(30), m_w_supertrend(20), m_w_zlema(10),
                     m_w_vwap(5), m_w_stddev(10), m_w_rsi(10),
                     m_w_volume(5), m_w_keltner(10), m_threshold(65) {}

   //+------------------------------------------------------------------+
   //| Configure weights for BB EA                                       |
   //+------------------------------------------------------------------+
   void InitBB()
   {
      m_w_primary    = 30;   // BB touch/close-back-inside
      m_w_supertrend = 20;
      m_w_keltner    = 15;   // NOT in squeeze
      m_w_stddev     = 10;
      m_w_zlema      = 10;
      m_w_vwap       = 5;
      m_w_rsi        = 5;
      m_w_volume     = 5;
      m_threshold    = 65;
   }

   //+------------------------------------------------------------------+
   //| Configure weights for Pattern EA                                  |
   //+------------------------------------------------------------------+
   void InitPattern()
   {
      m_w_primary    = 30;   // Pattern bias (mandatory)
      m_w_supertrend = 20;
      m_w_zlema      = 15;
      m_w_vwap       = 10;
      m_w_stddev     = 10;
      m_w_rsi        = 10;
      m_w_volume     = 5;
      m_w_keltner    = 0;    // Not used in pattern EA
      m_threshold    = 65;
   }

   void SetThreshold(int threshold) { m_threshold = threshold; }

   //+------------------------------------------------------------------+
   //| Calculate score from boolean filter results                       |
   //+------------------------------------------------------------------+
   SignalScore Calculate(int direction,
                         bool primary_ok,
                         bool supertrend_ok,
                         bool zlema_ok,
                         bool vwap_ok,
                         bool stddev_ok,
                         bool rsi_ok,
                         bool volume_ok,
                         bool keltner_ok = true)
   {
      SignalScore s;
      ZeroMemory(s);

      s.direction     = direction;
      s.primary_valid = primary_ok;
      s.primary       = primary_ok;
      s.supertrend    = supertrend_ok;
      s.zlema         = zlema_ok;
      s.vwap          = vwap_ok;
      s.stddev        = stddev_ok;
      s.rsi           = rsi_ok;
      s.volume        = volume_ok;
      s.keltner       = keltner_ok;

      //--- Primary signal is mandatory
      if(!primary_ok)
      {
         s.total_score = 0;
         s.direction   = DIR_NONE;
         return s;
      }

      //--- Sum weighted scores
      s.total_score = m_w_primary;
      if(supertrend_ok) s.total_score += m_w_supertrend;
      if(zlema_ok)      s.total_score += m_w_zlema;
      if(vwap_ok)       s.total_score += m_w_vwap;
      if(stddev_ok)     s.total_score += m_w_stddev;
      if(rsi_ok)        s.total_score += m_w_rsi;
      if(volume_ok)     s.total_score += m_w_volume;
      if(keltner_ok)    s.total_score += m_w_keltner;

      //--- Below threshold = no trade
      if(s.total_score < m_threshold)
         s.direction = DIR_NONE;

      return s;
   }

   //--- Accessors
   int GetThreshold() { return m_threshold; }
};

#endif
