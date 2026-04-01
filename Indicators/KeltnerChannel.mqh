//+------------------------------------------------------------------+
//| KeltnerChannel.mqh                                                |
//| Keltner Channel: EMA ± ATR * multiplier                          |
//| Primary use: BB squeeze detection (BB inside KC = squeeze)       |
//+------------------------------------------------------------------+
#ifndef KELTNER_CHANNEL_MQH
#define KELTNER_CHANNEL_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CKeltnerChannel                                                   |
//+------------------------------------------------------------------+
class CKeltnerChannel
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_ema_handle;
   int               m_atr_handle;
   double            m_multiplier;

   double ReadBuffer(int handle, int shift)
   {
      double buf[];
      if(handle == INVALID_HANDLE) return 0;
      if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0;
      return buf[0];
   }

public:
   CKeltnerChannel() : m_ema_handle(INVALID_HANDLE),
                       m_atr_handle(INVALID_HANDLE), m_multiplier(2.0) {}

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int ema_period, int atr_period, double multiplier)
   {
      m_symbol     = symbol;
      m_tf         = tf;
      m_multiplier = multiplier;

      m_ema_handle = iMA(symbol, tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_ema_handle == INVALID_HANDLE)
      {
         Print("[Keltner] Failed to create EMA(", ema_period, ") handle");
         return false;
      }

      m_atr_handle = iATR(symbol, tf, atr_period);
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("[Keltner] Failed to create ATR(", atr_period, ") handle");
         return false;
      }

      return true;
   }

   void Deinit()
   {
      if(m_ema_handle != INVALID_HANDLE) IndicatorRelease(m_ema_handle);
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
      m_ema_handle = INVALID_HANDLE;
      m_atr_handle = INVALID_HANDLE;
   }

   //--- Channel values
   double GetMiddle(int shift = 1) { return ReadBuffer(m_ema_handle, shift); }

   double GetUpper(int shift = 1)
   {
      double ema = ReadBuffer(m_ema_handle, shift);
      double atr = ReadBuffer(m_atr_handle, shift);
      return ema + m_multiplier * atr;
   }

   double GetLower(int shift = 1)
   {
      double ema = ReadBuffer(m_ema_handle, shift);
      double atr = ReadBuffer(m_atr_handle, shift);
      return ema - m_multiplier * atr;
   }

   //+------------------------------------------------------------------+
   //| BB Squeeze Detection                                              |
   //| Squeeze ON when BB bands are INSIDE Keltner Channel              |
   //| bb_upper < kc_upper AND bb_lower > kc_lower = SQUEEZE           |
   //+------------------------------------------------------------------+
   bool IsBBSqueeze(double bb_upper, double bb_lower, int shift = 1)
   {
      double kc_upper = GetUpper(shift);
      double kc_lower = GetLower(shift);
      if(kc_upper <= 0 || kc_lower <= 0) return false;

      return (bb_upper < kc_upper && bb_lower > kc_lower);
   }

   //+------------------------------------------------------------------+
   //| Squeeze firing: BB expanding outside KC after being inside       |
   //+------------------------------------------------------------------+
   bool IsSqueezeFiring(double bb_upper, double bb_lower,
                        double bb_upper_prev, double bb_lower_prev, int shift = 1)
   {
      //--- Were we in squeeze on previous bar?
      double kc_upper_prev = GetUpper(shift + 1);
      double kc_lower_prev = GetLower(shift + 1);
      bool was_squeeze = (bb_upper_prev < kc_upper_prev && bb_lower_prev > kc_lower_prev);

      //--- Are we out of squeeze now?
      bool is_squeeze = IsBBSqueeze(bb_upper, bb_lower, shift);

      return (was_squeeze && !is_squeeze);
   }
};

#endif
