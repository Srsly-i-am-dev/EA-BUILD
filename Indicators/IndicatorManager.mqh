//+------------------------------------------------------------------+
//| IndicatorManager.mqh                                              |
//| Creates and manages indicator handles — shared by both EAs        |
//| Parameterized: periods/timeframes passed at Init(), not hardcoded |
//+------------------------------------------------------------------+
#ifndef INDICATOR_MANAGER_MQH
#define INDICATOR_MANAGER_MQH

//+------------------------------------------------------------------+
//| CIndicatorManager                                                 |
//| Manages iRSI, iATR, iMA, iStdDev handles for a given symbol      |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   string            m_symbol;

   //--- RSI
   int               m_rsi_handle;
   int               m_rsi_period;
   ENUM_TIMEFRAMES   m_rsi_tf;

   //--- ATR short (e.g., 96 for grid, 14 for scalp)
   int               m_atr_short_handle;
   int               m_atr_short_period;
   ENUM_TIMEFRAMES   m_atr_short_tf;

   //--- ATR long (e.g., 672 for grid, 96 for scalp)
   int               m_atr_long_handle;
   int               m_atr_long_period;
   ENUM_TIMEFRAMES   m_atr_long_tf;

   //--- MA for Bollinger Band basis
   int               m_ma_handle;
   int               m_ma_period;
   ENUM_TIMEFRAMES   m_ma_tf;

   //--- StdDev for Bollinger Band calculation
   int               m_stddev_handle;
   int               m_stddev_period;
   ENUM_TIMEFRAMES   m_stddev_tf;

   //--- EMA(200) for trend filter (WakaScalp only)
   int               m_ema_trend_handle;
   int               m_ema_trend_period;
   ENUM_TIMEFRAMES   m_ema_trend_tf;

   //--- Helper: read single value from indicator buffer
   double ReadBuffer(int handle, int shift = 1)
   {
      double buf[];
      if(handle == INVALID_HANDLE) return 0.0;
      if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
      return buf[0];
   }

public:
   CIndicatorManager()
   {
      m_symbol            = "";
      m_rsi_handle        = INVALID_HANDLE;
      m_atr_short_handle  = INVALID_HANDLE;
      m_atr_long_handle   = INVALID_HANDLE;
      m_ma_handle         = INVALID_HANDLE;
      m_stddev_handle     = INVALID_HANDLE;
      m_ema_trend_handle  = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Initialize all indicator handles                                  |
   //+------------------------------------------------------------------+
   bool Init(string symbol,
             int rsi_period,       ENUM_TIMEFRAMES rsi_tf,
             int atr_short_period, ENUM_TIMEFRAMES atr_short_tf,
             int atr_long_period,  ENUM_TIMEFRAMES atr_long_tf,
             int ma_period,        ENUM_TIMEFRAMES ma_tf,
             int stddev_period,    ENUM_TIMEFRAMES stddev_tf,
             int ema_trend_period = 0, ENUM_TIMEFRAMES ema_trend_tf = PERIOD_M15)
   {
      m_symbol = symbol;

      //--- RSI
      m_rsi_period = rsi_period;
      m_rsi_tf     = rsi_tf;
      m_rsi_handle = iRSI(symbol, rsi_tf, rsi_period, PRICE_CLOSE);
      if(m_rsi_handle == INVALID_HANDLE)
      {
         Print("[IndMgr] Failed to create RSI(", rsi_period, ") handle");
         return false;
      }

      //--- ATR short
      m_atr_short_period = atr_short_period;
      m_atr_short_tf     = atr_short_tf;
      m_atr_short_handle = iATR(symbol, atr_short_tf, atr_short_period);
      if(m_atr_short_handle == INVALID_HANDLE)
      {
         Print("[IndMgr] Failed to create ATR(", atr_short_period, ") handle");
         return false;
      }

      //--- ATR long
      m_atr_long_period = atr_long_period;
      m_atr_long_tf     = atr_long_tf;
      m_atr_long_handle = iATR(symbol, atr_long_tf, atr_long_period);
      if(m_atr_long_handle == INVALID_HANDLE)
      {
         Print("[IndMgr] Failed to create ATR(", atr_long_period, ") handle");
         return false;
      }

      //--- MA (Bollinger Band basis)
      m_ma_period = ma_period;
      m_ma_tf     = ma_tf;
      m_ma_handle = iMA(symbol, ma_tf, ma_period, 0, MODE_SMA, PRICE_CLOSE);
      if(m_ma_handle == INVALID_HANDLE)
      {
         Print("[IndMgr] Failed to create MA(", ma_period, ") handle");
         return false;
      }

      //--- StdDev (Bollinger Band width)
      m_stddev_period = stddev_period;
      m_stddev_tf     = stddev_tf;
      m_stddev_handle = iStdDev(symbol, stddev_tf, stddev_period, 0, MODE_SMA, PRICE_CLOSE);
      if(m_stddev_handle == INVALID_HANDLE)
      {
         Print("[IndMgr] Failed to create StdDev(", stddev_period, ") handle");
         return false;
      }

      //--- EMA trend filter (optional, for WakaScalp)
      if(ema_trend_period > 0)
      {
         m_ema_trend_period = ema_trend_period;
         m_ema_trend_tf     = ema_trend_tf;
         m_ema_trend_handle = iMA(symbol, ema_trend_tf, ema_trend_period, 0, MODE_EMA, PRICE_CLOSE);
         if(m_ema_trend_handle == INVALID_HANDLE)
         {
            Print("[IndMgr] Failed to create EMA(", ema_trend_period, ") handle");
            return false;
         }
      }

      Print("[IndMgr] Initialized: RSI(", rsi_period, ") ATR(", atr_short_period,
            "/", atr_long_period, ") MA(", ma_period, ") StdDev(", stddev_period, ")",
            (ema_trend_period > 0 ? " EMA(" + IntegerToString(ema_trend_period) + ")" : ""));
      return true;
   }

   //+------------------------------------------------------------------+
   //| Release all handles                                               |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      if(m_rsi_handle       != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
      if(m_atr_short_handle != INVALID_HANDLE) IndicatorRelease(m_atr_short_handle);
      if(m_atr_long_handle  != INVALID_HANDLE) IndicatorRelease(m_atr_long_handle);
      if(m_ma_handle        != INVALID_HANDLE) IndicatorRelease(m_ma_handle);
      if(m_stddev_handle    != INVALID_HANDLE) IndicatorRelease(m_stddev_handle);
      if(m_ema_trend_handle != INVALID_HANDLE) IndicatorRelease(m_ema_trend_handle);

      m_rsi_handle       = INVALID_HANDLE;
      m_atr_short_handle = INVALID_HANDLE;
      m_atr_long_handle  = INVALID_HANDLE;
      m_ma_handle        = INVALID_HANDLE;
      m_stddev_handle    = INVALID_HANDLE;
      m_ema_trend_handle = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Value readers (shift=1 = completed bar, shift=0 = current bar)   |
   //+------------------------------------------------------------------+
   double GetRSI(int shift = 1)        { return ReadBuffer(m_rsi_handle, shift); }
   double GetATRShort(int shift = 1)   { return ReadBuffer(m_atr_short_handle, shift); }
   double GetATRLong(int shift = 1)    { return ReadBuffer(m_atr_long_handle, shift); }
   double GetMA(int shift = 1)         { return ReadBuffer(m_ma_handle, shift); }
   double GetStdDev(int shift = 1)     { return ReadBuffer(m_stddev_handle, shift); }
   double GetEMATrend(int shift = 1)   { return ReadBuffer(m_ema_trend_handle, shift); }

   //--- Read multiple values for slope detection
   bool GetEMATrendValues(double &current, double &previous, int bars_back = 5)
   {
      current  = ReadBuffer(m_ema_trend_handle, 1);
      previous = ReadBuffer(m_ema_trend_handle, bars_back);
      return (current != 0.0 && previous != 0.0);
   }

   //--- Handle accessors (for advanced use)
   int RSIHandle()       { return m_rsi_handle; }
   int ATRShortHandle()  { return m_atr_short_handle; }
   int ATRLongHandle()   { return m_atr_long_handle; }
   int MAHandle()        { return m_ma_handle; }
   int StdDevHandle()    { return m_stddev_handle; }
   int EMATrendHandle()  { return m_ema_trend_handle; }
};

#endif
