//+------------------------------------------------------------------+
//| RSISignal.mqh                                                     |
//| RSI-based buy/sell signal logic — shared by both EAs              |
//+------------------------------------------------------------------+
#ifndef RSI_SIGNAL_MQH
#define RSI_SIGNAL_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CRSISignal                                                        |
//| WakaGrid: threshold-based (RSI crosses 35/65)                    |
//| WakaScalp: recovery-based (RSI recovers back through 30/70)      |
//+------------------------------------------------------------------+
class CRSISignal
{
private:
   double m_center;       // RSI center (50)
   double m_deviation;    // Distance from center (e.g., 15 for 35/65)
   bool   m_reverse;      // Reverse strategy flag

public:
   CRSISignal() : m_center(50.0), m_deviation(15.0), m_reverse(false) {}

   void Init(double deviation, bool reverse = false)
   {
      m_deviation = deviation;
      m_reverse   = reverse;
   }

   //--- Threshold boundaries
   double GetBuyThreshold()  { return m_center - m_deviation; }  // e.g., 35
   double GetSellThreshold() { return m_center + m_deviation; }  // e.g., 65

   //+------------------------------------------------------------------+
   //| WakaGrid signal: simple threshold crossing                        |
   //| Returns DIR_BUY, DIR_SELL, or DIR_NONE                           |
   //+------------------------------------------------------------------+
   int CheckThreshold(double rsi_value)
   {
      int signal = DIR_NONE;

      if(rsi_value < GetBuyThreshold())
         signal = DIR_BUY;
      else if(rsi_value > GetSellThreshold())
         signal = DIR_SELL;

      if(m_reverse && signal != DIR_NONE)
         signal = (signal == DIR_BUY) ? DIR_SELL : DIR_BUY;

      return signal;
   }

   //+------------------------------------------------------------------+
   //| WakaScalp signal: RSI recovery confirmation                       |
   //| Buy: prev RSI was below buy_threshold, now above (recovering)    |
   //| Sell: prev RSI was above sell_threshold, now below (recovering)  |
   //| Returns DIR_BUY, DIR_SELL, or DIR_NONE                           |
   //+------------------------------------------------------------------+
   int CheckRecovery(double rsi_current, double rsi_previous)
   {
      double buy_level  = GetBuyThreshold();
      double sell_level = GetSellThreshold();

      int signal = DIR_NONE;

      // Buy: was below threshold, now crossing back above
      if(rsi_previous < buy_level && rsi_current >= buy_level)
         signal = DIR_BUY;
      // Sell: was above threshold, now crossing back below
      else if(rsi_previous > sell_level && rsi_current <= sell_level)
         signal = DIR_SELL;

      if(m_reverse && signal != DIR_NONE)
         signal = (signal == DIR_BUY) ? DIR_SELL : DIR_BUY;

      return signal;
   }
};

#endif
