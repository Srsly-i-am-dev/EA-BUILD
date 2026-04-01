//+------------------------------------------------------------------+
//| SessionFilter.mqh                                                 |
//| Three-tier session system for WakaScalp                          |
//| Asian=BLOCKED, London=ALLOWED, Overlap=PRIMARY, NY=ALLOWED       |
//+------------------------------------------------------------------+
#ifndef SESSION_FILTER_MQH
#define SESSION_FILTER_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CSessionFilter                                                    |
//+------------------------------------------------------------------+
class CSessionFilter
{
private:
   int    m_london_start;    // UTC hour
   int    m_overlap_start;   // UTC hour
   int    m_overlap_end;     // UTC hour
   int    m_ny_end;          // UTC hour
   ENUM_SCALP_PROFILE m_profile;

public:
   CSessionFilter() : m_london_start(7), m_overlap_start(12),
                       m_overlap_end(16), m_ny_end(21),
                       m_profile(SCALP_BALANCED) {}

   void Init(int london_start, int overlap_start, int overlap_end, int ny_end,
             ENUM_SCALP_PROFILE profile)
   {
      m_london_start  = london_start;
      m_overlap_start = overlap_start;
      m_overlap_end   = overlap_end;
      m_ny_end        = ny_end;
      m_profile       = profile;
   }

   //+------------------------------------------------------------------+
   //| Get current UTC hour                                              |
   //+------------------------------------------------------------------+
   int GetUTCHour()
   {
      MqlDateTime t;
      TimeToStruct(TimeGMT(), t);
      return t.hour;
   }

   int GetUTCMinute()
   {
      MqlDateTime t;
      TimeToStruct(TimeGMT(), t);
      return t.min;
   }

   //+------------------------------------------------------------------+
   //| Is rollover period? (23:45 - 00:15 UTC)                          |
   //+------------------------------------------------------------------+
   bool IsRollover()
   {
      int h = GetUTCHour();
      int m = GetUTCMinute();
      int total_mins = h * 60 + m;

      // 23:45 to 00:15
      return (total_mins >= 23 * 60 + 45 || total_mins <= 0 * 60 + 15);
   }

   //+------------------------------------------------------------------+
   //| Is within overlap session? (12:00-16:00 UTC)                      |
   //+------------------------------------------------------------------+
   bool IsOverlap()
   {
      int h = GetUTCHour();
      return (h >= m_overlap_start && h < m_overlap_end);
   }

   //+------------------------------------------------------------------+
   //| Can trade based on profile and session                            |
   //+------------------------------------------------------------------+
   bool CanTrade()
   {
      if(IsRollover()) return false;

      int h = GetUTCHour();

      //--- Weekend check
      MqlDateTime t;
      TimeToStruct(TimeGMT(), t);
      if(t.day_of_week == 0 || t.day_of_week == 6) return false;

      switch(m_profile)
      {
         case SCALP_CONSERVATIVE:
            // Overlap only (12:00-16:00)
            return (h >= m_overlap_start && h < m_overlap_end);

         case SCALP_BALANCED:
            // London + NY (07:00-21:00)
            return (h >= m_london_start && h < m_ny_end);

         case SCALP_ACTIVE:
            // All except Asian (00-07) and rollover
            return (h >= m_london_start || h >= 21);
            // Actually: everything except 00:15-07:00
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Get session name for panel display                                |
   //+------------------------------------------------------------------+
   string GetCurrentSession()
   {
      if(IsRollover()) return "ROLLOVER";
      int h = GetUTCHour();
      if(h >= m_overlap_start && h < m_overlap_end) return "OVERLAP";
      if(h >= m_london_start && h < m_overlap_start) return "LONDON";
      if(h >= m_overlap_end && h < m_ny_end) return "NEW YORK";
      return "OFF-HOURS";
   }

   ENUM_SCALP_PROFILE GetProfile() { return m_profile; }
};

#endif
