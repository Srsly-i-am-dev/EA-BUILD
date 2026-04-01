//+------------------------------------------------------------------+
//| LotCalculator.mqh                                                 |
//| Lot sizing methods + martingale multipliers for WakaGrid          |
//+------------------------------------------------------------------+
#ifndef LOT_CALCULATOR_MQH
#define LOT_CALCULATOR_MQH

#include "../Core/Defines.mqh"
#include "../Utils/SymbolInfo.mqh"

//+------------------------------------------------------------------+
//| CLotCalculator                                                    |
//+------------------------------------------------------------------+
class CLotCalculator
{
private:
   CSymbolHelper *m_sym;
   ENUM_LOT_METHOD m_method;

   //--- Fixed lot
   double m_fixed_lot;

   //--- Deposit load
   double m_deposit_load_pct;  // e.g., 0.25, 0.5, 1.0, 1.5

   //--- Dynamic lot
   double m_dynamic_amount;    // Balance per 0.01 lot (e.g., 10000)

   //--- Martingale multipliers
   double m_mult_2nd;          // Level 2 multiplier (default 1.0)
   double m_mult_3to5;         // Level 3-5 multiplier (default 2.0)
   double m_mult_6plus;        // Level 6+ multiplier (default 1.6)

   //--- Fixed initial deposit (tester mode)
   bool   m_use_fixed_deposit;
   double m_fixed_deposit;

public:
   CLotCalculator() : m_sym(NULL), m_method(LOT_FIXED), m_fixed_lot(0.01),
                      m_deposit_load_pct(0.25), m_dynamic_amount(10000.0),
                      m_mult_2nd(1.0), m_mult_3to5(2.0), m_mult_6plus(1.6),
                      m_use_fixed_deposit(false), m_fixed_deposit(0.0) {}

   void Init(CSymbolHelper &sym, ENUM_LOT_METHOD method,
             double fixed_lot, double deposit_load_pct, double dynamic_amount,
             double mult_2nd, double mult_3to5, double mult_6plus)
   {
      m_sym              = &sym;
      m_method           = method;
      m_fixed_lot        = fixed_lot;
      m_deposit_load_pct = deposit_load_pct;
      m_dynamic_amount   = dynamic_amount;
      m_mult_2nd         = mult_2nd;
      m_mult_3to5        = mult_3to5;
      m_mult_6plus       = mult_6plus;
   }

   void SetFixedDeposit(bool use, double amount)
   {
      m_use_fixed_deposit = use;
      m_fixed_deposit     = amount;
   }

   //+------------------------------------------------------------------+
   //| Get effective balance for lot calculation                          |
   //+------------------------------------------------------------------+
   double GetEffectiveBalance()
   {
      if(m_use_fixed_deposit && m_fixed_deposit > 0)
         return m_fixed_deposit;
      return AccountInfoDouble(ACCOUNT_BALANCE);
   }

   //+------------------------------------------------------------------+
   //| Calculate base lot size (level 0/1, before multipliers)           |
   //+------------------------------------------------------------------+
   double CalcBaseLot()
   {
      double lot = m_fixed_lot;
      double balance = GetEffectiveBalance();

      switch(m_method)
      {
         case LOT_FIXED:
            lot = m_fixed_lot;
            break;

         case LOT_DEPOSIT_LOAD:
            lot = CalcDepositLoadLot(balance, m_deposit_load_pct);
            break;

         case LOT_DYNAMIC:
            lot = CalcDynamicLot(balance);
            break;

         case LOT_PRESET_LOW:
            lot = CalcDepositLoadLot(balance, 0.25);
            break;

         case LOT_PRESET_MED:
            lot = CalcDepositLoadLot(balance, 0.5);
            break;

         case LOT_PRESET_SIG:
            lot = CalcDepositLoadLot(balance, 1.0);
            break;

         case LOT_PRESET_HIGH:
            lot = CalcDepositLoadLot(balance, 1.5);
            break;
      }

      return m_sym.NormalizeLot(lot);
   }

   //+------------------------------------------------------------------+
   //| Calculate lot for a specific grid level (with martingale)         |
   //| Level 0 = base trade, Level 1 = first grid, etc.                 |
   //+------------------------------------------------------------------+
   double CalcLotForLevel(int level)
   {
      double lot = CalcBaseLot();

      // Level 0 (base): 1x
      if(level <= 0) return lot;

      // Level 1: mult_2nd (default 1.0 = same as base)
      lot *= m_mult_2nd;
      if(level == 1) return m_sym.NormalizeLot(lot);

      // Level 2-4: mult_3to5 compounding
      for(int i = 2; i <= level && i <= 4; i++)
         lot *= m_mult_3to5;
      if(level <= 4) return m_sym.NormalizeLot(lot);

      // Level 5+: mult_6plus compounding
      for(int i = 5; i <= level; i++)
         lot *= m_mult_6plus;

      return m_sym.NormalizeLot(lot);
   }

   //+------------------------------------------------------------------+
   //| Deposit load lot calculation                                      |
   //+------------------------------------------------------------------+
   double CalcDepositLoadLot(double balance, double load_pct)
   {
      if(m_sym == NULL) return m_fixed_lot;
      double ask = m_sym.Ask();
      double contract = m_sym.ContractSize();
      if(ask <= 0 || contract <= 0) return m_fixed_lot;

      double lot = balance * (load_pct / 100.0) / (contract * ask);
      return MathMax(lot, m_sym.LotMin());
   }

   //+------------------------------------------------------------------+
   //| Dynamic lot: 0.01 per dynamic_amount of balance                   |
   //+------------------------------------------------------------------+
   double CalcDynamicLot(double balance)
   {
      if(m_dynamic_amount <= 0) return m_fixed_lot;
      return (balance / m_dynamic_amount) * 0.01;
   }

   //--- Accessors
   ENUM_LOT_METHOD Method()  { return m_method; }
   double Mult2nd()          { return m_mult_2nd; }
   double Mult3to5()         { return m_mult_3to5; }
   double Mult6plus()        { return m_mult_6plus; }
};

#endif
