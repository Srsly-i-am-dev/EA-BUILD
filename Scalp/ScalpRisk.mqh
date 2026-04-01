//+------------------------------------------------------------------+
//| ScalpRisk.mqh                                                     |
//| Throttler + DD compression + daily loss cap for WakaScalp        |
//| Adapted from scalper/MT5/Core/RiskCompression.mqh                 |
//+------------------------------------------------------------------+
#ifndef SCALP_RISK_MQH
#define SCALP_RISK_MQH

#include "../Core/Defines.mqh"
#include "../Risk/DrawdownMonitor.mqh"
#include "../Utils/SymbolInfo.mqh"

//+------------------------------------------------------------------+
//| CScalpRisk                                                        |
//| Integrates: throttling, DD compression, exposure cap, daily loss   |
//+------------------------------------------------------------------+
class CScalpRisk
{
private:
   //--- Throttling
   int      m_max_per_hour;
   int      m_max_per_day;
   int      m_trades_hour;
   int      m_trades_day;
   datetime m_hour_reset;
   datetime m_day_reset;
   datetime m_last_open;
   int      m_min_hold_sec;

   //--- Consecutive loss cooldown
   int      m_consecutive_losses;
   int      m_max_consec_losses;
   int      m_cooldown_sec;
   int      m_base_delay_sec;
   datetime m_cooldown_until;

   //--- Loss streak progressive delay
   int      m_loss_streak;

   //--- DD compression thresholds (matching existing scalper)
   // 0-3%: 100%, 3-5%: 75%, 5-8%: 50%, 8-10%: 25%, 10%+: hard stop

   //--- Exposure cap
   double   m_max_exposure;
   double   m_max_lots;

   //--- Daily loss cap
   double   m_max_daily_loss;
   string   m_symbol;
   int      m_magic;

public:
   CScalpRisk() : m_max_per_hour(10), m_max_per_day(50),
                  m_trades_hour(0), m_trades_day(0),
                  m_hour_reset(0), m_day_reset(0), m_last_open(0),
                  m_min_hold_sec(60), m_consecutive_losses(0),
                  m_max_consec_losses(3), m_cooldown_sec(120),
                  m_base_delay_sec(120), m_cooldown_until(0),
                  m_loss_streak(0), m_max_exposure(1.5), m_max_lots(0.5),
                  m_max_daily_loss(100.0), m_symbol(""), m_magic(0) {}

   void Init(string symbol, int magic,
             int max_per_hour, int max_per_day,
             int max_consec, int cooldown_sec,
             double max_lots, double max_exposure,
             double max_daily_loss, int min_hold_sec)
   {
      m_symbol           = symbol;
      m_magic            = magic;
      m_max_per_hour     = max_per_hour;
      m_max_per_day      = max_per_day;
      m_max_consec_losses= max_consec;
      m_cooldown_sec     = cooldown_sec;
      m_base_delay_sec   = cooldown_sec;
      m_max_lots         = max_lots;
      m_max_exposure     = max_exposure;
      m_max_daily_loss   = max_daily_loss;
      m_min_hold_sec     = min_hold_sec;
      m_hour_reset       = TimeTradeServer();
      m_day_reset        = TimeTradeServer();
   }

   //+------------------------------------------------------------------+
   //| Sync trade counters at hour/day boundaries                        |
   //+------------------------------------------------------------------+
   void SyncCounters()
   {
      datetime now = TimeTradeServer();

      if((now - m_hour_reset) >= 3600)
      {
         m_trades_hour = 0;
         m_hour_reset  = now;
      }

      MqlDateTime d_now, d_last;
      TimeToStruct(now, d_now);
      TimeToStruct(m_day_reset, d_last);
      if(d_now.day != d_last.day || d_now.mon != d_last.mon)
      {
         m_trades_day = 0;
         m_day_reset  = now;
      }
   }

   //+------------------------------------------------------------------+
   //| Primary gate: can we open a new trade?                            |
   //+------------------------------------------------------------------+
   bool CanTrade()
   {
      SyncCounters();
      datetime now = TimeTradeServer();

      if(now < m_cooldown_until) return false;
      if(m_trades_hour >= m_max_per_hour) return false;
      if(m_trades_day  >= m_max_per_day)  return false;

      return true;
   }

   //+------------------------------------------------------------------+
   //| DD compression: scale lots based on drawdown                      |
   //+------------------------------------------------------------------+
   double CompressLots(double base_lots, CDrawdownMonitor &dd)
   {
      double dd_pct = dd.GetFloatingDDPct();
      double factor = 1.0;

      if     (dd_pct >= 10.0) return 0.0;   // Hard stop
      else if(dd_pct >= 8.0)  factor = 0.25;
      else if(dd_pct >= 5.0)  factor = 0.50;
      else if(dd_pct >= 3.0)  factor = 0.75;

      double lots = base_lots * factor;
      lots = MathMin(lots, m_max_lots);
      return lots;
   }

   //+------------------------------------------------------------------+
   //| Check exposure cap                                                |
   //+------------------------------------------------------------------+
   bool CanAddLots(double lots)
   {
      double total = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == m_symbol)
            total += PositionGetDouble(POSITION_VOLUME);
      }
      return (total + lots) <= m_max_exposure;
   }

   //+------------------------------------------------------------------+
   //| Check daily loss cap                                              |
   //+------------------------------------------------------------------+
   bool IsDailyLossBreached()
   {
      if(m_max_daily_loss <= 0) return false;

      MqlDateTime d;
      TimeToStruct(TimeTradeServer(), d);
      d.hour = 0; d.min = 0; d.sec = 0;
      datetime from = StructToTime(d);

      if(!HistorySelect(from, TimeTradeServer()))
         return false;

      double pnl = 0.0;
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol) continue;
         if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic) continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

         pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT)
              + HistoryDealGetDouble(ticket, DEAL_SWAP)
              + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }

      return (pnl <= -m_max_daily_loss);
   }

   //+------------------------------------------------------------------+
   //| Record trade open                                                 |
   //+------------------------------------------------------------------+
   void RecordOpen()
   {
      m_last_open = TimeTradeServer();
      m_trades_hour++;
      m_trades_day++;
   }

   //+------------------------------------------------------------------+
   //| Record trade close result                                         |
   //+------------------------------------------------------------------+
   void RecordClose(double profit)
   {
      if(profit < 0)
      {
         m_consecutive_losses++;
         m_loss_streak++;
         if(m_consecutive_losses >= m_max_consec_losses)
         {
            // Progressive cooldown
            int delay = m_base_delay_sec + (m_loss_streak * 60);
            m_cooldown_until     = TimeTradeServer() + delay;
            m_consecutive_losses = 0;
         }
      }
      else
      {
         m_consecutive_losses = 0;
         m_loss_streak        = 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Has position been held long enough?                               |
   //+------------------------------------------------------------------+
   bool HasOpenPosition()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != m_symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) == m_magic)
            return true;
      }
      return false;
   }

   //--- Accessors
   int    TradesToday()      { return m_trades_day; }
   int    TradesThisHour()   { return m_trades_hour; }
   int    LossStreak()       { return m_loss_streak; }
   double MaxLots()          { return m_max_lots; }
   double DailyPnl()         { return 0; } // placeholder for panel
};

#endif
