//+------------------------------------------------------------------+
//| SpreadFilter.mqh                                                  |
//| Max spread/slippage gate — shared by both EAs                     |
//+------------------------------------------------------------------+
#ifndef SPREAD_FILTER_MQH
#define SPREAD_FILTER_MQH

//+------------------------------------------------------------------+
//| CSpreadFilter                                                     |
//| Blocks trading when spread exceeds maximum threshold               |
//+------------------------------------------------------------------+
class CSpreadFilter
{
private:
   int    m_max_spread_pts;
   string m_symbol;

public:
   CSpreadFilter() : m_max_spread_pts(50), m_symbol("") {}

   void Init(string symbol, int max_spread_pts)
   {
      m_symbol         = symbol;
      m_max_spread_pts = max_spread_pts;
   }

   //--- Returns true if spread is within acceptable range
   bool IsSpreadOK()
   {
      int spread = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      return (spread <= m_max_spread_pts);
   }

   //--- Get current spread in points
   int GetSpreadPoints()
   {
      return (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }

   //--- Get current spread in price
   double GetSpreadPrice()
   {
      return GetSpreadPoints() * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   }

   void SetMaxSpread(int pts) { m_max_spread_pts = pts; }
   int  GetMaxSpread()        { return m_max_spread_pts; }
};

#endif
