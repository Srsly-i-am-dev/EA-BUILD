//+------------------------------------------------------------------+
//| TradeExecutor.mqh                                                 |
//| CTrade wrapper for order execution — shared by both EAs           |
//+------------------------------------------------------------------+
#ifndef TRADE_EXECUTOR_MQH
#define TRADE_EXECUTOR_MQH

#include <Trade/Trade.mqh>
#include "../Utils/SymbolInfo.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CTradeExecutor                                                    |
//| Thin wrapper around CTrade with magic number, slippage, filling   |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   CTrade         m_trade;
   CSymbolHelper *m_sym;
   CLogger       *m_log;
   int            m_slippage_pts;

public:
   CTradeExecutor() : m_sym(NULL), m_log(NULL), m_slippage_pts(30) {}

   void Init(CSymbolHelper &sym, CLogger &log, int magic, int slippage_pts = 30)
   {
      m_sym           = &sym;
      m_log           = &log;
      m_slippage_pts  = slippage_pts;

      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage_pts);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   }

   //+------------------------------------------------------------------+
   //| Open a market buy order                                           |
   //+------------------------------------------------------------------+
   bool OpenBuy(double lots, double sl_price, double tp_price, string comment = "")
   {
      double ask = m_sym.Ask();
      sl_price = m_sym.NormalizePrice(sl_price);
      tp_price = m_sym.NormalizePrice(tp_price);

      bool ok = m_trade.Buy(lots, m_sym.Symbol(), ask, sl_price, tp_price, comment);
      if(ok)
      {
         if(m_log != NULL)
            m_log.Info("BUY " + DoubleToString(lots, 2) + " @ " + DoubleToString(ask, m_sym.Digits())
                       + " SL=" + DoubleToString(sl_price, m_sym.Digits())
                       + " TP=" + DoubleToString(tp_price, m_sym.Digits())
                       + " " + comment);
      }
      else
      {
         if(m_log != NULL)
            m_log.Warn("BUY FAILED lots=" + DoubleToString(lots, 2)
                       + " err=" + IntegerToString(GetLastError()));
      }
      return ok;
   }

   //+------------------------------------------------------------------+
   //| Open a market sell order                                          |
   //+------------------------------------------------------------------+
   bool OpenSell(double lots, double sl_price, double tp_price, string comment = "")
   {
      double bid = m_sym.Bid();
      sl_price = m_sym.NormalizePrice(sl_price);
      tp_price = m_sym.NormalizePrice(tp_price);

      bool ok = m_trade.Sell(lots, m_sym.Symbol(), bid, sl_price, tp_price, comment);
      if(ok)
      {
         if(m_log != NULL)
            m_log.Info("SELL " + DoubleToString(lots, 2) + " @ " + DoubleToString(bid, m_sym.Digits())
                       + " SL=" + DoubleToString(sl_price, m_sym.Digits())
                       + " TP=" + DoubleToString(tp_price, m_sym.Digits())
                       + " " + comment);
      }
      else
      {
         if(m_log != NULL)
            m_log.Warn("SELL FAILED lots=" + DoubleToString(lots, 2)
                       + " err=" + IntegerToString(GetLastError()));
      }
      return ok;
   }

   //+------------------------------------------------------------------+
   //| Modify position SL/TP                                             |
   //+------------------------------------------------------------------+
   bool ModifyPosition(ulong ticket, double sl_price, double tp_price)
   {
      sl_price = m_sym.NormalizePrice(sl_price);
      tp_price = m_sym.NormalizePrice(tp_price);
      return m_trade.PositionModify(ticket, sl_price, tp_price);
   }

   //+------------------------------------------------------------------+
   //| Close a specific position                                         |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket, string comment = "")
   {
      bool ok = m_trade.PositionClose(ticket, m_slippage_pts);
      if(ok)
      {
         if(m_log != NULL)
            m_log.Info("CLOSED ticket=" + IntegerToString(ticket) + " " + comment);
      }
      else
      {
         if(m_log != NULL)
            m_log.Warn("CLOSE FAILED ticket=" + IntegerToString(ticket)
                       + " err=" + IntegerToString(GetLastError()));
      }
      return ok;
   }

   //+------------------------------------------------------------------+
   //| Close all positions matching magic on current symbol              |
   //+------------------------------------------------------------------+
   void CloseAllByMagic(int magic, string reason = "")
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != m_sym.Symbol()) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

         ulong ticket = PositionGetTicket(i);
         ClosePosition(ticket, reason);
      }
   }

   //+------------------------------------------------------------------+
   //| Close all positions matching magic AND direction                   |
   //+------------------------------------------------------------------+
   void CloseAllByDirection(int magic, int direction, string reason = "")
   {
      ENUM_POSITION_TYPE target_type = (direction == DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != m_sym.Symbol()) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != target_type) continue;

         ulong ticket = PositionGetTicket(i);
         ClosePosition(ticket, reason);
      }
   }

   //--- Accessor
   CTrade *GetTrade() { return &m_trade; }
};

#endif
