//+------------------------------------------------------------------+
//| WakaScalp.mq5                                                     |
//| XAUUSD Scalping EA — BB + RSI mean-reversion with trend filter   |
//| Phase 3: 4-layer confluence signal + first trade                  |
//+------------------------------------------------------------------+
#property copyright "WakaScalp EA"
#property version   "0.30"
#property strict

//--- Include all modules
#include "Scalp/Inputs_Scalp.mqh"
#include "Scalp/Globals_Scalp.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Logger
   g_log.Init("[WakaScalp]", InpSDebugMode);
   g_log.Info("Initializing v0.30...");

   //--- Symbol info
   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to initialize symbol info for " + _Symbol);
      return INIT_FAILED;
   }

   //--- Indicators: RSI(10) M5, ATR(14) M5, ATR(96) M5, MA(20) M5, StdDev(21) M5, EMA(200) M15
   if(!g_indicators.Init(_Symbol,
         InpSRSIPeriod,     PERIOD_M5,         // RSI(10) on M5
         InpSATRPeriod,     PERIOD_M5,         // ATR short (14) on M5
         InpSATRLongPeriod, PERIOD_M5,         // ATR long (96) on M5
         InpSBBPeriod,      PERIOD_M5,         // MA(20) for BB on M5
         InpSBBPeriod + 1,  PERIOD_M5,         // StdDev(21) for BB on M5
         InpSEMAPeriod,     PERIOD_M15))       // EMA(200) on M15
   {
      g_log.Error("Failed to create indicator handles");
      return INIT_FAILED;
   }

   //--- Signal engine (4-layer confluence)
   g_signal.Init((double)InpSRSIDeviation, InpSBBDeviation,
                 InpSEMASlopeShift, 0.5,               // slope_bars, chop_mult
                 InpSVolMult, InpSVolWindow,
                 InpSATRMinGate, InpSSqueezeThresh);

   //--- TP/SL calculator
   g_tp.Init(InpSTP_ATRMult, InpSSL_ATRMult,
             InpSTP_SpreadMult, InpSSL_SpreadMult,
             InpSMinTP_Points, InpSMaxTP_Points,
             InpSMinSL_Points, InpSMaxSL_Points,
             InpSMinRR, InpSSmartTP);

   //--- Trade executor
   g_executor.Init(g_sym, g_log, InpSMagic, 30);  // 30pt slippage for XAUUSD

   //--- Position management (breakeven, trailing, time-stop)
   g_scalp_exec.Init(g_executor, g_sym, _Symbol, InpSMagic,
                     InpSBreakevenPct, InpSTrailPct, InpSTrailDistPct,
                     InpSTimeStopBars, InpSMinHoldSec);

   //--- Risk management (throttler, DD compression, daily loss)
   g_scalp_risk.Init(_Symbol, InpSMagic,
                     InpSMaxPerHour, InpSMaxPerDay,
                     InpSMaxConsecLoss, InpSCooldownSec,
                     InpSMaxLots, InpSMaxExposure,
                     InpSMaxDailyLoss, InpSMinHoldSec);

   //--- Session filter
   g_session.Init(InpSLondonStart, InpSOverlapStart, InpSOverlapEnd, InpSNYEnd,
                  InpScalpProfile);

   //--- Spread filter
   g_spread_filter.Init(_Symbol, InpSMaxSpread);

   //--- Margin check
   g_margin_check.Init(0.0);  // No fixed margin floor; DD compression handles risk

   //--- News filter
   g_news_filter.Init(InpSNewsFilter, InpSNewsBefore, InpSNewsAfter);

   //--- Drawdown monitor
   g_dd_monitor.Update();

   //--- Initialize new bar detector (skip first tick)
   g_new_bar.Reset(_Symbol, PERIOD_M5);

   g_log.Info("Initialized on " + _Symbol + " M5"
              + " Profile=" + EnumToString(InpScalpProfile)
              + " RSI(" + IntegerToString(InpSRSIPeriod) + ")"
              + " BB(" + IntegerToString(InpSBBPeriod) + ")"
              + " EMA(" + IntegerToString(InpSEMAPeriod) + ") M15"
              + " BaseLot=" + DoubleToString(InpSBaseLots, 2));
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
   //--- Always update drawdown monitor (every tick)
   g_dd_monitor.Update();

   //--- Always manage open positions (breakeven, trailing, time-stop) every tick
   g_scalp_exec.ManagePositions();

   //--- Signal check only on new M5 bar
   if(!g_new_bar.IsNewBar(_Symbol, PERIOD_M5))
      return;

   //--- Gate 1: Allow trades input
   if(!InpSAllowTrades) return;

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

   //--- Gate 5: Risk throttler (hourly/daily limits, cooldown)
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
   int signal = g_signal.CheckSignal(g_indicators, _Symbol, PERIOD_M5);
   if(signal == DIR_NONE)
   {
      if(InpSDebugMode)
         g_log.Debug("Signal rejected: " + g_signal.GetRejectReason());
      return;
   }

   //--- Direction filter
   if(InpSTradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpSTradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   //--- Calculate dynamic TP/SL
   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   if(!g_tp.Calculate(g_indicators, g_sym, *g_signal.GetBB(), entry_price, signal))
   {
      g_log.Debug("TP/SL skipped: R:R below minimum");
      return;
   }

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   //--- Lot sizing with DD compression
   double base_lots = InpSBaseLots;
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
   string comment = InpSTradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
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
                 + " ATR=" + DoubleToString(g_indicators.GetATRShort(1), 2)
                 + " Session=" + g_session.GetCurrentSession());
   }
   else
   {
      g_log.Warn("Failed to open trade");
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler — track wins/losses for risk throttler  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;

   //--- Only process closed positions (exits)
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) return;

   //--- Check it belongs to our EA
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpSMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   //--- Feed result to risk throttler for consecutive loss tracking
   g_scalp_risk.RecordClose(profit);

   g_log.Info("Position closed. Profit=" + DoubleToString(profit, 2)
              + " Streak=" + IntegerToString(g_scalp_risk.LossStreak())
              + " Today=" + IntegerToString(g_scalp_risk.TradesToday()));
}
//+------------------------------------------------------------------+
