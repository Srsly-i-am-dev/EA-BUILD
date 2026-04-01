//+------------------------------------------------------------------+
//| WakaGrid.mq5                                                      |
//| Waka Waka-style Grid/Martingale Expert Advisor                    |
//| Phase 2: RSI entry signal + first trade with basic TP/SL          |
//+------------------------------------------------------------------+
#property copyright "WakaGrid EA"
#property version   "0.20"
#property strict

//--- Include all modules
#include "Core/Inputs_Grid.mqh"
#include "Core/Globals_Grid.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Logger
   g_log.Init("[WakaGrid]", InpDebugMode);
   g_log.Info("Initializing v0.20...");

   //--- Symbol info
   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to initialize symbol info for " + _Symbol);
      return INIT_FAILED;
   }

   //--- Indicators: RSI(20), ATR(96), ATR(672), MA(35), StdDev(36) on working TF
   if(!g_indicators.Init(_Symbol,
         InpRSIPeriod,  InpWorkingTF,           // RSI
         InpATRShort,   InpWorkingTF,           // ATR short
         InpATRLong,    InpWorkingTF,           // ATR long
         InpBBPeriod,   InpWorkingTF,           // MA (BB basis)
         InpBBPeriod+1, InpWorkingTF))          // StdDev (BB period + 1)
   {
      g_log.Error("Failed to create indicator handles");
      return INIT_FAILED;
   }

   //--- RSI signal (deviation from 50)
   g_rsi_signal.Init((double)InpRSIValue, InpReverseStrategy);

   //--- Bollinger Band calculator
   g_bb_calc.Init(2.0);

   //--- ATR volatility (smart distance)
   g_atr_vol.Init(1.0, 1.5);

   //--- Magic number
   g_magic.Init(InpMagicBase);

   //--- Lot calculator
   g_lot_calc.Init(g_sym, InpLotMethod, InpFixedLot, InpDepositLoadPct,
                   InpDynamicAmount, InpMult2nd, InpMult3to5, InpMult6plus);
   if(InpFixedInitDeposit && MQLInfoInteger(MQL_TESTER))
      g_lot_calc.SetFixedDeposit(true, InpInitDeposit);

   //--- Trade executor
   g_executor.Init(g_sym, g_log, g_magic.Encode(DIR_BUY, 0),
                   (int)g_sym.PipsToPoints(InpMaxSlippage));

   //--- Risk components
   g_spread_filter.Init(_Symbol, (int)g_sym.PipsToPoints(InpMaxSpread));
   g_margin_check.Init(InpMinFreeMargin);

   //--- Time filter
   g_time_filter.Init(InpHourStart, InpHourStop,
                      InpRolloverStart, InpRolloverStartM,
                      InpRolloverEnd, InpRolloverEndM,
                      InpTradeMon, InpTradeTue, InpTradeWed,
                      InpTradeThu, InpTradeFri,
                      InpAutoGMT, InpGMTOffset);

   //--- News filter
   g_news_filter.Init(InpNewsFilter, InpNewsBefore, InpNewsAfter);

   //--- Initialize new bar detector (skip first tick)
   g_new_bar.Reset(_Symbol, InpWorkingTF);

   g_log.Info("Initialized on " + _Symbol + " " + EnumToString(InpWorkingTF)
              + " RSI(" + IntegerToString(InpRSIPeriod) + ") BB(" + IntegerToString(InpBBPeriod) + ")"
              + " Buy<" + IntegerToString(50 - InpRSIValue) + " Sell>" + IntegerToString(50 + InpRSIValue));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_indicators.Deinit();
   g_log.Info("Deinitialized. Reason=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Count open positions for this EA in a direction                   |
//+------------------------------------------------------------------+
int CountPositions(int direction)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      int pos_magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(!g_magic.BelongsToEA(pos_magic)) continue;

      if(direction == DIR_NONE)
      {
         count++;
      }
      else
      {
         int pos_dir = CMagicNumber::DecodeDirection(pos_magic);
         if(pos_dir == direction) count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Always update drawdown monitor (every tick)
   g_dd_monitor.Update();

   //--- Only process on new bar
   if(!g_new_bar.IsNewBar(_Symbol, InpWorkingTF))
      return;

   //--- Check if trading is allowed
   if(!InpAllowNewTrades) return;
   if(!g_time_filter.CanTradeNow()) return;
   if(!g_news_filter.CanTradeNews()) return;
   if(!g_spread_filter.IsSpreadOK())
   {
      g_log.Debug("Spread too wide: " + IntegerToString(g_spread_filter.GetSpreadPoints()) + " pts");
      return;
   }

   //--- Read RSI value (completed bar = shift 1)
   double rsi_value = g_indicators.GetRSI(1);
   if(rsi_value == 0.0) return;

   g_log.Debug("RSI=" + DoubleToString(rsi_value, 2));

   //--- Check RSI signal (threshold mode for WakaGrid)
   int signal = g_rsi_signal.CheckThreshold(rsi_value);
   if(signal == DIR_NONE) return;

   //--- Filter by trade direction setting
   if(InpTradeDirection == TRADE_BUY_ONLY && signal == DIR_SELL) return;
   if(InpTradeDirection == TRADE_SELL_ONLY && signal == DIR_BUY) return;

   //--- Check if we already have a position in this direction (base trade)
   if(CountPositions(signal) > 0)
   {
      g_log.Debug("Already have position in direction " + IntegerToString(signal));
      return;
   }

   //--- Check hedging rule
   if(!InpAllowHedging)
   {
      int opposite = (signal == DIR_BUY) ? DIR_SELL : DIR_BUY;
      if(CountPositions(opposite) > 0)
      {
         g_log.Debug("Hedging not allowed, opposite grid active");
         return;
      }
   }

   //--- Calculate lot size (base trade = level 0)
   double lots = g_lot_calc.CalcLotForLevel(0);

   //--- Margin check
   ENUM_ORDER_TYPE order_type = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, order_type, lots))
   {
      g_log.Warn("Insufficient margin for " + DoubleToString(lots, 2) + " lots");
      return;
   }

   //--- Calculate TP and SL
   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   double tp_distance = g_sym.PipsToPrice(InpInitialTP);
   double sl_distance = g_sym.PipsToPrice((InpStopLoss > 0) ? InpStopLoss : 1000.0);

   double tp_price, sl_price;
   if(signal == DIR_BUY)
   {
      tp_price = entry_price + tp_distance;
      sl_price = entry_price - sl_distance;
   }
   else
   {
      tp_price = entry_price - tp_distance;
      sl_price = entry_price + sl_distance;
   }

   //--- Build magic number and comment
   int magic = g_magic.Encode(signal, 0);
   string comment = InpTradeComment + "_" + IntegerToString(InpMagicBase)
                    + "_" + ((signal == DIR_BUY) ? "B" : "S") + "_L0";

   //--- Set magic on executor for this trade
   g_executor.Init(g_sym, g_log, magic, (int)g_sym.PipsToPoints(InpMaxSlippage));

   //--- Open trade
   bool result = false;
   if(signal == DIR_BUY)
      result = g_executor.OpenBuy(lots, sl_price, tp_price, comment);
   else
      result = g_executor.OpenSell(lots, sl_price, tp_price, comment);

   if(result)
      g_log.Info("Base trade opened: " + ((signal == DIR_BUY) ? "BUY" : "SELL")
                 + " " + DoubleToString(lots, 2) + " lots"
                 + " RSI=" + DoubleToString(rsi_value, 2));
   else
      g_log.Warn("Failed to open base trade");
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal))
   {
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
      {
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                       + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                       + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
         g_log.Debug("Position closed. Profit=" + DoubleToString(profit, 2));
      }
   }
}
//+------------------------------------------------------------------+
