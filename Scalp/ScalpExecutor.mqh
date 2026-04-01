//+------------------------------------------------------------------+
//| ScalpExecutor.mqh                                                 |
//| Position management: breakeven, trailing, time-stop               |
//| Adapted from scalper/Trend-Pullback_scalp.mq5 ManagePositions()  |
//+------------------------------------------------------------------+
#ifndef SCALP_EXECUTOR_MQH
#define SCALP_EXECUTOR_MQH

#include "../Core/Defines.mqh"
#include "../Trading/TradeExecutor.mqh"
#include "../Utils/SymbolInfo.mqh"

//+------------------------------------------------------------------+
//| CScalpExecutor                                                    |
//| Handles breakeven, trailing, and time-stop per tick               |
//+------------------------------------------------------------------+
class CScalpExecutor
{
private:
   CTradeExecutor *m_exec;
   CSymbolHelper  *m_sym;

   //--- Breakeven + trailing (as % of TP distance)
   double m_breakeven_pct;   // e.g., 50.0 (trigger at 50% of TP)
   double m_trail_pct;       // e.g., 100.0 (activate at 100% of TP)
   double m_trail_dist_pct;  // e.g., 40.0 (trail at 40% of TP distance)

   //--- Time-stop
   int    m_time_stop_bars;  // Close after N M5 bars
   int    m_min_hold_sec;

   //--- Track TP distance per position (stored as entry+tp from order)
   int    m_magic;
   string m_symbol;

public:
   CScalpExecutor() : m_exec(NULL), m_sym(NULL),
                       m_breakeven_pct(50.0), m_trail_pct(100.0),
                       m_trail_dist_pct(40.0), m_time_stop_bars(5),
                       m_min_hold_sec(60), m_magic(0), m_symbol("") {}

   void Init(CTradeExecutor &exec, CSymbolHelper &sym,
             string symbol, int magic,
             double be_pct, double trail_pct, double trail_dist_pct,
             int time_stop_bars, int min_hold_sec)
   {
      m_exec           = &exec;
      m_sym            = &sym;
      m_symbol         = symbol;
      m_magic          = magic;
      m_breakeven_pct  = be_pct;
      m_trail_pct      = trail_pct;
      m_trail_dist_pct = trail_dist_pct;
      m_time_stop_bars = time_stop_bars;
      m_min_hold_sec   = min_hold_sec;
   }

   //+------------------------------------------------------------------+
   //| Manage all open positions — call every tick                       |
   //+------------------------------------------------------------------+
   void ManagePositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != m_symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         ulong ticket    = PositionGetTicket(i);
         double entry    = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         bool is_buy = (pos_type == POSITION_TYPE_BUY);

         double current_price = is_buy ? m_sym.Bid() : m_sym.Ask();

         //--- Calculate profit in price units
         double profit_price = is_buy ? (current_price - entry) : (entry - current_price);

         //--- Calculate TP distance from order (entry to TP)
         double tp_distance = 0;
         if(current_tp > 0)
            tp_distance = MathAbs(current_tp - entry);

         if(tp_distance <= 0) continue;

         //--- Min hold check
         datetime now = TimeTradeServer();
         int hold_secs = (int)(now - open_time);
         if(hold_secs < m_min_hold_sec) continue;

         //--- Time-stop: close after N M5 bars (N * 300 seconds)
         if(m_time_stop_bars > 0)
         {
            int time_limit = m_time_stop_bars * 300;  // M5 = 300 sec
            if(hold_secs >= time_limit)
            {
               m_exec.ClosePosition(ticket, "TimeStop");
               continue;
            }
         }

         //--- Breakeven: when profit reaches breakeven_pct % of TP, move SL to entry
         double be_trigger = tp_distance * (m_breakeven_pct / 100.0);
         if(profit_price >= be_trigger)
         {
            double be_sl = entry;
            // Only modify if current SL is worse than breakeven
            if(is_buy && (current_sl < be_sl || current_sl == 0))
            {
               m_exec.ModifyPosition(ticket, be_sl, current_tp);
            }
            else if(!is_buy && (current_sl > be_sl || current_sl == 0))
            {
               m_exec.ModifyPosition(ticket, be_sl, current_tp);
            }
         }

         //--- Trailing: when profit reaches trail_pct % of TP, trail SL
         double trail_trigger = tp_distance * (m_trail_pct / 100.0);
         if(profit_price >= trail_trigger)
         {
            double trail_dist = tp_distance * (m_trail_dist_pct / 100.0);
            double new_sl;

            if(is_buy)
            {
               new_sl = current_price - trail_dist;
               if(new_sl > current_sl)
                  m_exec.ModifyPosition(ticket, new_sl, current_tp);
            }
            else
            {
               new_sl = current_price + trail_dist;
               if(new_sl < current_sl || current_sl == 0)
                  m_exec.ModifyPosition(ticket, new_sl, current_tp);
            }
         }
      }
   }
};

#endif
