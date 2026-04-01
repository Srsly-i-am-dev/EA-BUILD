//+------------------------------------------------------------------+
//| PatternMatcher.mqh                                                |
//| Cosine similarity pattern recognition engine                      |
//| Ported from "1 min Perfect Strategy" GoldPatternDashboardEA       |
//| Scans history for candle patterns similar to current formation    |
//+------------------------------------------------------------------+
#ifndef PATTERN_MATCHER_MQH
#define PATTERN_MATCHER_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| Pattern scan result structure                                     |
//+------------------------------------------------------------------+
struct PatternResult
{
   int    total_matches;
   int    up_matches;
   int    down_matches;
   int    flat_matches;
   double up_accuracy;     // 0-100
   double down_accuracy;   // 0-100
   double avg_net_move;
   double avg_up_move;
   double avg_down_move;
   int    bias;            // DIR_BUY, DIR_SELL, DIR_NONE
   double confidence;      // max(up_acc, down_acc)
};

//+------------------------------------------------------------------+
//| CPatternMatcher                                                   |
//+------------------------------------------------------------------+
class CPatternMatcher
{
private:
   int    m_lookback_bars;
   int    m_future_bars;
   double m_similarity_threshold;
   bool   m_use_wicks;
   int    m_pattern_candles;
   int    m_max_matches;

   PatternResult m_result;

   //+------------------------------------------------------------------+
   //| Build normalized pattern vector from rate data                    |
   //+------------------------------------------------------------------+
   bool BuildVector(const MqlRates &rates[], int start, int count, double &vec[])
   {
      if(count < 2) return false;
      int total = ArraySize(rates);
      if(start + count >= total) return false;

      int dim = count * (m_use_wicks ? 4 : 2);
      ArrayResize(vec, dim);

      //--- Find max range for normalization
      double max_range = 0;
      for(int i = 0; i < count; i++)
      {
         double rg = rates[start + i].high - rates[start + i].low;
         if(rg > max_range) max_range = rg;
      }
      if(max_range <= 0) return false;

      int p = 0;
      for(int i = 0; i < count; i++)
      {
         double o = rates[start + i].open;
         double h = rates[start + i].high;
         double l = rates[start + i].low;
         double c = rates[start + i].close;

         vec[p++] = (c - o) / max_range;               // body ratio
         vec[p++] = (h - l) / max_range;               // range ratio
         if(m_use_wicks)
         {
            vec[p++] = (h - MathMax(o, c)) / max_range; // upper wick
            vec[p++] = (MathMin(o, c) - l) / max_range; // lower wick
         }
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Cosine similarity between two vectors                             |
   //+------------------------------------------------------------------+
   double CosineSim(const double &a[], const double &b[])
   {
      int n = ArraySize(a);
      if(n != ArraySize(b) || n == 0) return 0;

      double dot = 0, na = 0, nb = 0;
      for(int i = 0; i < n; i++)
      {
         dot += a[i] * b[i];
         na  += a[i] * a[i];
         nb  += b[i] * b[i];
      }
      if(na <= 0 || nb <= 0) return 0;
      return dot / MathSqrt(na * nb);
   }

public:
   CPatternMatcher() : m_lookback_bars(5000), m_future_bars(10),
                       m_similarity_threshold(0.80), m_use_wicks(true),
                       m_pattern_candles(5), m_max_matches(100) {}

   void Init(int lookback_bars, int future_bars, double similarity, bool use_wicks)
   {
      m_lookback_bars       = lookback_bars;
      m_future_bars         = future_bars;
      m_similarity_threshold = similarity;
      m_use_wicks           = use_wicks;
      ZeroMemory(m_result);
   }

   void SetPatternLength(int candles)    { m_pattern_candles = candles; }
   void SetMaxMatches(int max_matches)   { m_max_matches = max_matches; }
   void SetThreshold(double threshold)   { m_similarity_threshold = threshold; }

   //+------------------------------------------------------------------+
   //| Scan history for pattern matches and derive directional bias      |
   //+------------------------------------------------------------------+
   bool ScanForBias(string symbol, ENUM_TIMEFRAMES tf)
   {
      ZeroMemory(m_result);

      //--- Load rates
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int need = m_lookback_bars + m_future_bars + m_pattern_candles + 50;
      int copied = CopyRates(symbol, tf, 0, need, rates);
      if(copied <= m_pattern_candles + m_future_bars + 30) return false;

      //--- Build current pattern vector (from shift 1 = completed bars)
      double current_vec[];
      if(!BuildVector(rates, 1, m_pattern_candles, current_vec)) return false;

      //--- Scan history
      int bars = ArraySize(rates);
      int start_scan = m_pattern_candles + m_future_bars + 5;
      int end_scan   = MathMin(m_lookback_bars, bars - m_pattern_candles - 2);
      int matches = 0;

      double sum_up = 0, sum_down = 0, sum_net = 0;

      for(int shift = start_scan; shift <= end_scan; shift++)
      {
         double hist_vec[];
         if(!BuildVector(rates, shift, m_pattern_candles, hist_vec)) continue;

         double sim = CosineSim(current_vec, hist_vec);
         if(sim < m_similarity_threshold) continue;

         matches++;

         //--- Future move after pattern
         double start_close  = rates[shift].close;
         double future_close = rates[shift - m_future_bars].close;
         double move = future_close - start_close;

         sum_net += move;

         if(move > 0)
         {
            m_result.up_matches++;
            sum_up += move;
         }
         else if(move < 0)
         {
            m_result.down_matches++;
            sum_down += move;
         }
         else
         {
            m_result.flat_matches++;
         }

         if(matches >= m_max_matches) break;
      }

      m_result.total_matches = matches;

      if(matches <= 0)
      {
         m_result.bias = DIR_NONE;
         m_result.confidence = 0;
         return true;
      }

      //--- Calculate accuracies
      m_result.up_accuracy   = 100.0 * m_result.up_matches / matches;
      m_result.down_accuracy = 100.0 * m_result.down_matches / matches;
      m_result.avg_net_move  = sum_net / matches;

      if(m_result.up_matches > 0)
         m_result.avg_up_move = sum_up / m_result.up_matches;
      if(m_result.down_matches > 0)
         m_result.avg_down_move = sum_down / m_result.down_matches;

      //--- Determine bias
      if(m_result.up_matches > m_result.down_matches)
         m_result.bias = DIR_BUY;
      else if(m_result.down_matches > m_result.up_matches)
         m_result.bias = DIR_SELL;
      else
         m_result.bias = DIR_NONE;

      m_result.confidence = MathMax(m_result.up_accuracy, m_result.down_accuracy);

      return true;
   }

   //--- Accessors
   int    GetBias()          { return m_result.bias; }
   double GetUpAccuracy()    { return m_result.up_accuracy; }
   double GetDownAccuracy()  { return m_result.down_accuracy; }
   int    GetTotalMatches()  { return m_result.total_matches; }
   double GetConfidence()    { return m_result.confidence; }
   double GetAvgNetMove()    { return m_result.avg_net_move; }
   double GetAvgUpMove()     { return m_result.avg_up_move; }
   double GetAvgDownMove()   { return m_result.avg_down_move; }
   void GetResult(PatternResult &out) { out = m_result; }
};

#endif
