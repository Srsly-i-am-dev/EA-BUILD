//+------------------------------------------------------------------+
//| TwoPoleScalp.mq5                                                  |
//| Two-Pole Oscillator Scalping EA — mean-reversion with trend      |
//| 4-layer confluence: TwoPole + EMA(200) + RSI + Volume/ATR        |
//+------------------------------------------------------------------+
#property copyright "TwoPoleScalp EA"
#property version   "1.00"
#property strict

//--- Include all modules
#include "Scalp/Inputs_TwoPole.mqh"
#include "Scalp/Globals_TwoPole.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Logger
   g_log.Init("[TwoPoleScalp]", InpTPDebugMode);
   g_log.Info("Initializing v1.00...");

   //--- Symbol info
   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to initialize symbol info for " + _Symbol);
      return INIT_FAILED;
   }

   //--- Indicators: RSI, ATR short, ATR long, MA(20), StdDev(21), EMA(200) M15
   if(!g_indicators.Init(_Symbol,
         InpTPRSIPeriod,     PERIOD_M5,
         InpTPATRPeriod,     PERIOD_M5,
         InpTPATRLongPeriod, PERIOD_M5,
         20,                 PERIOD_M5,    // MA(20) for BB/TP calc
         21,                 PERIOD_M5,    // StdDev(21)
         InpTPEMAPeriod,     PERIOD_M15))
   {
      g_log.Error("Failed to create indicator handles");
      return INIT_FAILED;
   }

   //--- Two-Pole filter
   if(!g_twopole.Init(_Symbol, PERIOD_M5, InpTPFilterLength))
   {
      g_log.Error("Failed to init Two-Pole filter");
      return INIT_FAILED;
   }
   g_twopole.Warmup(300);

   //--- Signal engine (4-layer confluence)
   g_signal.Init((double)InpTPRSIDeviation,
                 InpTPEMASlopeShift, 0.5,
                 InpTPVolMult, InpTPVolWindow,
                 InpTPATRMinGate);

   //--- TP/SL calculator
   g_tp.Init(InpTPTP_ATRMult, InpTPSL_ATRMult,
             InpTPTP_SpreadMult, InpTPSL_SpreadMult,
             InpTPMinTP_Points, InpTPMaxTP_Points,
             InpTPMinSL_Points, InpTPMaxSL_Points,
             InpTPMinRR, InpTPSmartTP);

   //--- Trade executor
   g_executor.Init(g_sym, g_log, InpTPMagic, 30);

   //--- Position management
   g_scalp_exec.Init(g_executor, g_sym, _Symbol, InpTPMagic,
                     InpTPBreakevenPct, InpTPTrailPct, InpTPTrailDistPct,
                     InpTPTimeStopBars, InpTPMinHoldSec);

   //--- Risk management
   g_scalp_risk.Init(_Symbol, InpTPMagic,
                     InpTPMaxPerHour, InpTPMaxPerDay,
                     InpTPMaxConsecLoss, InpTPCooldownSec,
                     InpTPMaxLots, InpTPMaxExposure,
                     InpTPMaxDailyLoss, InpTPMinHoldSec);

   //--- Session filter
   g_session.Init(InpTPLondonStart, InpTPOverlapStart, InpTPOverlapEnd, InpTPNYEnd,
                  InpTPScalpProfile);

   //--- Spread filter
   g_spread_filter.Init(_Symbol, InpTPMaxSpread);

   //--- Margin check
   g_margin_check.Init(0.0);

   //--- News filter
   g_news_filter.Init(InpTPNewsFilter, InpTPNewsBefore, InpTPNewsAfter);

   //--- Drawdown monitor
   g_dd_monitor.Update();

   //--- Initialize new bar detector
   g_new_bar.Reset(_Symbol, PERIOD_M5);

   g_log.Info("Initialized on " + _Symbol + " M5"
              + " Profile=" + EnumToString(InpTPScalpProfile)
              + " TwoPole(" + IntegerToString(InpTPFilterLength) + ")"
              + " EMA(" + IntegerToString(InpTPEMAPeriod) + ") M15"
              + " BaseLot=" + DoubleToString(InpTPBaseLots, 2));
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
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Always update drawdown monitor
   g_dd_monitor.Update();

   //--- Always manage open positions
   g_scalp_exec.ManagePositions();

   //--- Signal check only on new M5 bar
   if(!g_new_bar.IsNewBar(_Symbol, PERIOD_M5))
      return;

   //--- Update Two-Pole filter on new bar
   g_twopole.Update(1);

   //--- Gate 1: Allow trades input
   if(!InpTPAllowTrades) return;

   //--- Gate 2: Session filter
   if(!g_session.CanTrade())
   {
      g_log.Debug("Session blocked: " + g_session.GetCurrentSession());
      return;
   }

   //--- Gate 3: News filter
   if(!g_news_filter.CanTradeNews()) return;

   //--- Gate 4: Spread filter
   if(!g_spread_filter.IsSpreadOK())
   {
      g_log.Debug("Spread too wide: " + IntegerToString(g_spread_filter.GetSpreadPoints()) + " pts");
      return;
   }

   //--- Gate 5: Risk throttler
   if(!g_scalp_risk.CanTrade())
   {
      g_log.Debug("Risk throttler blocked");
      return;
   }

   //--- Gate 6: Daily loss cap
   if(g_scalp_risk.IsDailyLossBreached())
   {
      g_log.Debug("Daily loss cap reached");
      return;
   }

   //--- Gate 7: Already have an open position
   if(g_scalp_risk.HasOpenPosition())
   {
      g_log.Debug("Position already open");
      return;
   }

   //--- 4-layer confluence signal check
   int signal = g_signal.CheckSignal(g_indicators, g_twopole, _Symbol, PERIOD_M5);
   if(signal == DIR_NONE)
   {
      if(InpTPDebugMode)
         g_log.Debug("Signal rejected: " + g_signal.GetRejectReason());
      return;
   }

   //--- Direction filter
   if(InpTPTradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpTPTradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   //--- Calculate dynamic TP/SL
   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   if(!g_tp.Calculate(g_indicators, g_sym, entry_price, signal))
   {
      g_log.Debug("TP/SL skipped: R:R below minimum");
      return;
   }

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   //--- Lot sizing with DD compression
   double base_lots = InpTPBaseLots;
   double lots = g_scalp_risk.CompressLots(base_lots, g_dd_monitor);
   if(lots <= 0)
   {
      g_log.Warn("DD hard stop — lots compressed to 0");
      return;
   }

   //--- Normalize lots
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, lot_min);

   //--- Exposure check
   if(!g_scalp_risk.CanAddLots(lots))
   {
      g_log.Debug("Exposure cap would be breached");
      return;
   }

   //--- Margin check
   ENUM_ORDER_TYPE order_type = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, order_type, lots))
   {
      g_log.Warn("Insufficient margin for " + DoubleToString(lots, 2) + " lots");
      return;
   }

   //--- Build trade comment
   string comment = InpTPTradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
                    + "_TP" + DoubleToString(g_tp.GetTPPoints(g_sym.Point()), 0)
                    + "_SL" + DoubleToString(g_tp.GetSLPoints(g_sym.Point()), 0);

   //--- Open trade
   bool result = false;
   if(signal == DIR_BUY)
      result = g_executor.OpenBuy(lots, sl_price, tp_price, comment);
   else
      result = g_executor.OpenSell(lots, sl_price, tp_price, comment);

   if(result)
   {
      g_scalp_risk.RecordOpen();
      g_log.Info(((signal == DIR_BUY) ? "BUY" : "SELL")
                 + " " + DoubleToString(lots, 2) + " lots"
                 + " TP=" + DoubleToString(tp_price, (int)g_sym.Digits())
                 + " SL=" + DoubleToString(sl_price, (int)g_sym.Digits())
                 + " TwoPole=" + DoubleToString(g_twopole.GetValue(), 3)
                 + " Session=" + g_session.GetCurrentSession());
   }
   else
   {
      g_log.Warn("Failed to open trade");
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) return;

   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpTPMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   g_scalp_risk.RecordClose(profit);

   g_log.Info("Position closed. Profit=" + DoubleToString(profit, 2)
              + " Streak=" + IntegerToString(g_scalp_risk.LossStreak())
              + " Today=" + IntegerToString(g_scalp_risk.TradesToday()));
}
//+------------------------------------------------------------------+
