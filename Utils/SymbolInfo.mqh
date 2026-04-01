//+------------------------------------------------------------------+
//| SymbolInfo.mqh                                                    |
//| Symbol information helpers — pip/point/digits normalization        |
//+------------------------------------------------------------------+
#ifndef SYMBOLINFO_MQH
#define SYMBOLINFO_MQH

//+------------------------------------------------------------------+
//| CSymbolHelper                                                     |
//| Provides normalized pip/point calculations for any symbol          |
//+------------------------------------------------------------------+
class CSymbolHelper
{
private:
   string m_symbol;
   double m_point;
   int    m_digits;
   double m_pip_size;       // 1 pip in price units
   double m_pip_to_points;  // how many points in 1 pip
   double m_lot_step;
   double m_lot_min;
   double m_lot_max;
   double m_tick_value;     // $ value of 1 point move per 1 lot
   double m_contract_size;

public:
   CSymbolHelper() : m_symbol(""), m_point(0), m_digits(0), m_pip_size(0),
                     m_pip_to_points(0), m_lot_step(0), m_lot_min(0), m_lot_max(0),
                     m_tick_value(0), m_contract_size(0) {}

   bool Init(string symbol)
   {
      m_symbol        = symbol;
      m_point         = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_digits        = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      m_lot_step      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      m_lot_min       = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      m_lot_max       = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      m_tick_value    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      m_contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

      if(m_point == 0) return false;

      // Determine pip size based on digits
      // Forex 5-digit: pip = 10 points (0.0001)
      // Forex 3-digit (JPY): pip = 10 points (0.01)
      // Gold (2-digit): pip = 1 point (0.01)
      // Gold (1-digit): pip = 1 point (0.1)
      if(m_digits == 5 || m_digits == 3)
      {
         m_pip_size      = m_point * 10.0;
         m_pip_to_points = 10.0;
      }
      else
      {
         m_pip_size      = m_point;
         m_pip_to_points = 1.0;
      }

      return true;
   }

   //--- Convert pips to price distance
   double PipsToPrice(double pips)
   {
      return pips * m_pip_size;
   }

   //--- Convert price distance to pips
   double PriceToPips(double price_dist)
   {
      if(m_pip_size == 0) return 0;
      return price_dist / m_pip_size;
   }

   //--- Convert pips to points
   double PipsToPoints(double pips)
   {
      return pips * m_pip_to_points;
   }

   //--- Convert points to pips
   double PointsToPips(double points)
   {
      if(m_pip_to_points == 0) return 0;
      return points / m_pip_to_points;
   }

   //--- Normalize lot to broker constraints
   double NormalizeLot(double lots)
   {
      if(m_lot_step == 0) return m_lot_min;
      lots = MathFloor(lots / m_lot_step) * m_lot_step;
      lots = MathMax(m_lot_min, MathMin(m_lot_max, lots));
      return NormalizeDouble(lots, 2);
   }

   //--- Normalize price to symbol digits
   double NormalizePrice(double price)
   {
      return NormalizeDouble(price, m_digits);
   }

   //--- Get current spread in points
   double GetSpreadPoints()
   {
      return (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }

   //--- Get current spread in price
   double GetSpreadPrice()
   {
      return GetSpreadPoints() * m_point;
   }

   //--- Accessors
   string Symbol()        { return m_symbol; }
   double Point()         { return m_point; }
   int    Digits()        { return m_digits; }
   double PipSize()       { return m_pip_size; }
   double PipToPoints()   { return m_pip_to_points; }
   double LotStep()       { return m_lot_step; }
   double LotMin()        { return m_lot_min; }
   double LotMax()        { return m_lot_max; }
   double TickValue()     { return m_tick_value; }
   double ContractSize()  { return m_contract_size; }
   double Ask()           { return SymbolInfoDouble(m_symbol, SYMBOL_ASK); }
   double Bid()           { return SymbolInfoDouble(m_symbol, SYMBOL_BID); }
};

#endif
