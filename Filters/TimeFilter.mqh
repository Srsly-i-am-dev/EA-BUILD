//+------------------------------------------------------------------+
//| TimeFilter.mqh                                                    |
//| Trading hours, day-of-week, rollover — shared by both EAs         |
//+------------------------------------------------------------------+
#ifndef TIME_FILTER_MQH
#define TIME_FILTER_MQH

//+------------------------------------------------------------------+
//| CTimeFilter                                                       |
//| Controls when trading is allowed based on time constraints         |
//+------------------------------------------------------------------+
class CTimeFilter
{
private:
   int  m_hour_start;       // Trading start hour (UTC)
   int  m_hour_stop;        // Trading stop hour (UTC)
   int  m_rollover_start;   // Rollover start hour (e.g., 23)
   int  m_rollover_start_min; // Rollover start minute (e.g., 45)
   int  m_rollover_end;     // Rollover end hour (e.g., 0)
   int  m_rollover_end_min; // Rollover end minute (e.g., 15)
   bool m_trade_monday;
   bool m_trade_tuesday;
   bool m_trade_wednesday;
   bool m_trade_thursday;
   bool m_trade_friday;
   int  m_gmt_offset;       // GMT offset in hours (0 = auto)
   bool m_auto_gmt;

public:
   CTimeFilter()
   {
      m_hour_start       = 0;
      m_hour_stop        = 24;
      m_rollover_start   = 23;
      m_rollover_start_min = 45;
      m_rollover_end     = 0;
      m_rollover_end_min = 15;
      m_trade_monday     = true;
      m_trade_tuesday    = true;
      m_trade_wednesday  = true;
      m_trade_thursday   = true;
      m_trade_friday     = true;
      m_gmt_offset       = 0;
      m_auto_gmt         = true;
   }

   void Init(int hour_start, int hour_stop,
             int rollover_start = 23, int rollover_start_min = 45,
             int rollover_end = 0, int rollover_end_min = 15,
             bool mon = true, bool tue = true, bool wed = true,
             bool thu = true, bool fri = true,
             bool auto_gmt = true, int gmt_offset = 0)
   {
      m_hour_start         = hour_start;
      m_hour_stop          = hour_stop;
      m_rollover_start     = rollover_start;
      m_rollover_start_min = rollover_start_min;
      m_rollover_end       = rollover_end;
      m_rollover_end_min   = rollover_end_min;
      m_trade_monday       = mon;
      m_trade_tuesday      = tue;
      m_trade_wednesday    = wed;
      m_trade_thursday     = thu;
      m_trade_friday       = fri;
      m_auto_gmt           = auto_gmt;
      m_gmt_offset         = gmt_offset;
   }

   //+------------------------------------------------------------------+
   //| Get current GMT hour (auto-detect or manual offset)               |
   //+------------------------------------------------------------------+
   int GetGMTHour()
   {
      MqlDateTime t;
      if(m_auto_gmt)
      {
         TimeToStruct(TimeGMT(), t);
      }
      else
      {
         TimeToStruct(TimeTradeServer(), t);
         t.hour -= m_gmt_offset;
         if(t.hour < 0) t.hour += 24;
         if(t.hour >= 24) t.hour -= 24;
      }
      return t.hour;
   }

   int GetGMTMinute()
   {
      MqlDateTime t;
      if(m_auto_gmt)
         TimeToStruct(TimeGMT(), t);
      else
         TimeToStruct(TimeTradeServer(), t);
      return t.min;
   }

   //+------------------------------------------------------------------+
   //| Is within allowed trading hours?                                  |
   //+------------------------------------------------------------------+
   bool IsWithinTradingHours()
   {
      int h = GetGMTHour();
      if(m_hour_start <= m_hour_stop)
         return (h >= m_hour_start && h < m_hour_stop);
      else
         return (h >= m_hour_start || h < m_hour_stop);
   }

   //+------------------------------------------------------------------+
   //| Is today a trading day?                                           |
   //+------------------------------------------------------------------+
   bool IsTradingDay()
   {
      MqlDateTime t;
      TimeToStruct(TimeTradeServer(), t);
      switch(t.day_of_week)
      {
         case 1: return m_trade_monday;
         case 2: return m_trade_tuesday;
         case 3: return m_trade_wednesday;
         case 4: return m_trade_thursday;
         case 5: return m_trade_friday;
         default: return false;  // Weekend
      }
   }

   //+------------------------------------------------------------------+
   //| Is in rollover period?                                            |
   //+------------------------------------------------------------------+
   bool IsRolloverPeriod()
   {
      int h = GetGMTHour();
      int m = GetGMTMinute();
      int current_mins = h * 60 + m;
      int roll_start   = m_rollover_start * 60 + m_rollover_start_min;
      int roll_end     = m_rollover_end * 60 + m_rollover_end_min;

      // Handle midnight crossing (e.g., 23:45 to 00:15)
      if(roll_start > roll_end)
         return (current_mins >= roll_start || current_mins <= roll_end);
      else
         return (current_mins >= roll_start && current_mins <= roll_end);
   }

   //+------------------------------------------------------------------+
   //| Combined check: can we trade right now?                           |
   //+------------------------------------------------------------------+
   bool CanTradeNow()
   {
      if(!IsTradingDay())       return false;
      if(!IsWithinTradingHours()) return false;
      if(IsRolloverPeriod())    return false;
      return true;
   }
};

#endif
