//+------------------------------------------------------------------+
//| DrawdownMonitor.mqh                                               |
//| Floating drawdown tracking — shared by both EAs                   |
//| Adapted from scalper/MT5/Core/RiskCompression.mqh                 |
//+------------------------------------------------------------------+
#ifndef DRAWDOWN_MONITOR_MQH
#define DRAWDOWN_MONITOR_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CDrawdownMonitor                                                  |
//| Tracks real-time floating drawdown from equity peak               |
//| Must call Update() on every tick                                  |
//+------------------------------------------------------------------+
class CDrawdownMonitor
{
private:
   double m_session_peak;
   double m_start_equity;
   double m_start_balance;

public:
   CDrawdownMonitor()
   {
      m_start_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      m_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_session_peak  = m_start_equity;
   }

   //--- Call on every tick to keep peak updated
   void Update()
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity > m_session_peak)
         m_session_peak = equity;
   }

   //--- Floating DD from session peak (%)
   double GetFloatingDDPct()
   {
      if(m_session_peak <= 0.0) return 0.0;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      return (m_session_peak - equity) / m_session_peak * 100.0;
   }

   //--- Floating DD from session peak ($)
   double GetFloatingDDMoney()
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      return m_session_peak - equity;
   }

   //--- Floating DD for EA-only positions
   double GetEAFloatingPnL(string symbol, int magic)
   {
      double pnl = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         pnl += PositionGetDouble(POSITION_PROFIT)
              + PositionGetDouble(POSITION_SWAP);
      }
      return pnl;
   }

   //--- Accessors
   double GetSessionPeak()  { return m_session_peak; }
   double GetStartEquity()  { return m_start_equity; }
   double GetStartBalance() { return m_start_balance; }
   double GetEquity()       { return AccountInfoDouble(ACCOUNT_EQUITY); }
   double GetBalance()      { return AccountInfoDouble(ACCOUNT_BALANCE); }
   double GetFreeMargin()   { return AccountInfoDouble(ACCOUNT_MARGIN_FREE); }
};

#endif
