//+------------------------------------------------------------------+
//| MarginCheck.mqh                                                   |
//| Free margin validation before trade — shared by both EAs          |
//+------------------------------------------------------------------+
#ifndef MARGIN_CHECK_MQH
#define MARGIN_CHECK_MQH

//+------------------------------------------------------------------+
//| CMarginCheck                                                      |
//| Validates sufficient margin before opening a position              |
//+------------------------------------------------------------------+
class CMarginCheck
{
private:
   double m_min_free_margin;

public:
   CMarginCheck() : m_min_free_margin(0.0) {}

   void Init(double min_free_margin)
   {
      m_min_free_margin = min_free_margin;
   }

   //+------------------------------------------------------------------+
   //| Check if opening a trade would leave sufficient free margin       |
   //+------------------------------------------------------------------+
   bool CanOpenTrade(string symbol, ENUM_ORDER_TYPE order_type, double lots)
   {
      //--- Basic free margin check
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(m_min_free_margin > 0 && free_margin < m_min_free_margin)
         return false;

      //--- Estimate required margin for the trade
      double margin_required = 0.0;
      double price = (order_type == ORDER_TYPE_BUY)
                     ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                     : SymbolInfoDouble(symbol, SYMBOL_BID);

      if(!OrderCalcMargin(order_type, symbol, lots, price, margin_required))
         return false;

      //--- Ensure free margin after trade is above minimum
      return (free_margin - margin_required) >= m_min_free_margin;
   }

   void SetMinFreeMargin(double val) { m_min_free_margin = val; }
   double GetMinFreeMargin()         { return m_min_free_margin; }
};

#endif
