//+------------------------------------------------------------------+
//| NewBar.mqh                                                        |
//| New-bar detection class — shared by both EAs                      |
//+------------------------------------------------------------------+
#ifndef NEWBAR_MQH
#define NEWBAR_MQH

//+------------------------------------------------------------------+
//| CNewBar                                                           |
//| Detects when a new bar opens on a given symbol/timeframe          |
//+------------------------------------------------------------------+
class CNewBar
{
private:
   datetime m_last_bar_time;

public:
   CNewBar() : m_last_bar_time(0) {}

   //--- Returns true once per new bar
   bool IsNewBar(string symbol, ENUM_TIMEFRAMES tf)
   {
      datetime bar_time = iTime(symbol, tf, 0);
      if(bar_time == 0) return false;

      if(bar_time != m_last_bar_time)
      {
         m_last_bar_time = bar_time;
         return true;
      }
      return false;
   }

   //--- Force reset (e.g., on init to avoid firing immediately)
   void Reset(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_last_bar_time = iTime(symbol, tf, 0);
   }

   datetime GetLastBarTime() { return m_last_bar_time; }
};

#endif
