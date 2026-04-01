//+------------------------------------------------------------------+
//| NewsFilter.mqh                                                    |
//| News event filter using MQL5 Economic Calendar — shared           |
//+------------------------------------------------------------------+
#ifndef NEWS_FILTER_MQH
#define NEWS_FILTER_MQH

//+------------------------------------------------------------------+
//| CNewsFilter                                                       |
//| Checks for high-impact news events within before/after window     |
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   bool   m_enabled;
   int    m_minutes_before;    // Minutes before event to block
   int    m_minutes_after;     // Minutes after event to block
   string m_currency;          // Currency to filter (e.g., "USD")

public:
   CNewsFilter() : m_enabled(false), m_minutes_before(15), m_minutes_after(10), m_currency("") {}

   void Init(bool enabled, int minutes_before, int minutes_after, string currency = "")
   {
      m_enabled        = enabled;
      m_minutes_before = minutes_before;
      m_minutes_after  = minutes_after;
      m_currency       = currency;
   }

   //+------------------------------------------------------------------+
   //| Check if trading should be blocked due to upcoming news           |
   //| Returns true if it is SAFE to trade (no news blocking)           |
   //+------------------------------------------------------------------+
   bool CanTradeNews()
   {
      if(!m_enabled) return true;

      datetime now    = TimeTradeServer();
      datetime from   = now - m_minutes_after * 60;
      datetime to     = now + m_minutes_before * 60;

      MqlCalendarValue values[];
      int count = CalendarValueHistory(values, from, to);

      if(count <= 0) return true;

      for(int i = 0; i < count; i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event))
            continue;

         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country))
            continue;

         //--- Filter by currency if specified
         if(m_currency != "" && country.currency != m_currency)
            continue;

         //--- Check if high-impact event
         if(event.importance == CALENDAR_IMPORTANCE_HIGH)
            return false;  // Block trading
      }

      return true;
   }

   //--- Accessors
   bool   IsEnabled()       { return m_enabled; }
   void   SetEnabled(bool v){ m_enabled = v; }
   int    MinutesBefore()   { return m_minutes_before; }
   int    MinutesAfter()    { return m_minutes_after; }
};

#endif
