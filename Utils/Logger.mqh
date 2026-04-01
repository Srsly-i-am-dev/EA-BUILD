//+------------------------------------------------------------------+
//| Logger.mqh                                                        |
//| Debug logging wrapper — shared by both EAs                        |
//+------------------------------------------------------------------+
#ifndef LOGGER_MQH
#define LOGGER_MQH

//+------------------------------------------------------------------+
//| CLogger                                                           |
//| Prefixed logging with debug mode toggle                           |
//+------------------------------------------------------------------+
class CLogger
{
private:
   string m_prefix;
   bool   m_debug;

public:
   CLogger() : m_prefix("[EA]"), m_debug(false) {}

   void Init(string prefix, bool debug_mode)
   {
      m_prefix = prefix;
      m_debug  = debug_mode;
   }

   void SetDebug(bool mode) { m_debug = mode; }
   bool IsDebug()           { return m_debug; }

   //--- Always prints (info level)
   void Info(string msg)
   {
      Print(m_prefix, " ", msg);
   }

   //--- Only prints if debug mode is on
   void Debug(string msg)
   {
      if(m_debug)
         Print(m_prefix, " [DBG] ", msg);
   }

   //--- Always prints (warning)
   void Warn(string msg)
   {
      Print(m_prefix, " [WARN] ", msg);
   }

   //--- Always prints + Alert (error)
   void Error(string msg)
   {
      Print(m_prefix, " [ERR] ", msg);
      Alert(m_prefix, " ERROR: ", msg);
   }
};

#endif
