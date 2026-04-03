//+------------------------------------------------------------------+
//| ZeroLagScalp.mq5                                                  |
//| Zero-Lag EMA Scalping EA — trend entry pullback system            |
//| 4-layer: ZLEMA entry + EMA(200) + RSI + Volume/ATR               |
//+------------------------------------------------------------------+
#property copyright "ZeroLagScalp EA"
#property version   "1.00"
#property strict

#include "Scalp/Inputs_ZeroLag.mqh"
#include "Scalp/Globals_ZeroLag.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
   g_log.Init("[ZeroLagScalp]", InpZLDebugMode);
   g_log.Info("Initializing v1.00...");

   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to init symbol info");
      return INIT_FAILED;
   }

   if(!g_indicators.Init(_Symbol,
         InpZLRSIPeriod,     PERIOD_M5,
         InpZLATRPeriod,     PERIOD_M5,
         InpZLATRLongPeriod, PERIOD_M5,
         20,                 PERIOD_M5,
         21,                 PERIOD_M5,
         InpZLTrendEMAPeriod, PERIOD_M15))
   {
      g_log.Error("Failed to create indicator handles");
      return INIT_FAILED;
   }

   if(!g_zlema.Init(_Symbol, PERIOD_M5, InpZLEMALength, InpZLBandMult))
   {
      g_log.Error("Failed to init ZLEMA");
      return INIT_FAILED;
   }
   g_zlema.Warmup(300);

   g_signal.Init((double)InpZLRSIDeviation,
                 InpZLEMASlopeShift, 0.5,
                 InpZLVolMult, InpZLVolWindow,
                 InpZLATRMinGate);

   g_tp.Init(InpZLTP_ATRMult, InpZLSL_ATRMult,
             InpZLTP_SpreadMult, InpZLSL_SpreadMult,
             InpZLMinTP_Points, InpZLMaxTP_Points,
             InpZLMinSL_Points, InpZLMaxSL_Points,
             InpZLMinRR, InpZLSmartTP);

   g_executor.Init(g_sym, g_log, InpZLMagic, 30);

   g_scalp_exec.Init(g_executor, g_sym, _Symbol, InpZLMagic,
                     InpZLBreakevenPct, InpZLTrailPct, InpZLTrailDistPct,
                     InpZLTimeStopBars, InpZLMinHoldSec);

   g_scalp_risk.Init(_Symbol, InpZLMagic,
                     InpZLMaxPerHour, InpZLMaxPerDay,
                     InpZLMaxConsecLoss, InpZLCooldownSec,
                     InpZLMaxLots, InpZLMaxExposure,
                     InpZLMaxDailyLoss, InpZLMinHoldSec);

   g_session.Init(InpZLLondonStart, InpZLOverlapStart, InpZLOverlapEnd, InpZLNYEnd,
                  InpZLScalpProfile);

   g_spread_filter.Init(_Symbol, InpZLMaxSpread);
   g_margin_check.Init(0.0);
   g_news_filter.Init(InpZLNewsFilter, InpZLNewsBefore, InpZLNewsAfter);
   g_dd_monitor.Update();
   g_new_bar.Reset(_Symbol, PERIOD_M5);

   g_log.Info("Initialized on " + _Symbol + " M5"
              + " ZLEMA(" + IntegerToString(InpZLEMALength) + ")"
              + " Band=" + DoubleToString(InpZLBandMult, 1)
              + " EMA(" + IntegerToString(InpZLTrendEMAPeriod) + ") M15");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_indicators.Deinit();
   g_zlema.Deinit();
   g_log.Info("Deinitialized. Reason=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
void OnTick()
{
   g_dd_monitor.Update();
   g_scalp_exec.ManagePositions();

   if(!g_new_bar.IsNewBar(_Symbol, PERIOD_M5))
      return;

   //--- Update ZLEMA on new bar
   g_zlema.Update(1);

   if(!InpZLAllowTrades) return;

   if(!g_session.CanTrade()) return;
   if(!g_news_filter.CanTradeNews()) return;
   if(!g_spread_filter.IsSpreadOK()) return;
   if(!g_scalp_risk.CanTrade()) return;
   if(g_scalp_risk.IsDailyLossBreached()) return;
   if(g_scalp_risk.HasOpenPosition()) return;

   int signal = g_signal.CheckSignal(g_indicators, g_zlema, _Symbol, PERIOD_M5);
   if(signal == DIR_NONE)
   {
      if(InpZLDebugMode)
         g_log.Debug("Signal rejected: " + g_signal.GetRejectReason());
      return;
   }

   if(InpZLTradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpZLTradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   CBollingerCalc dummy_bb;
   dummy_bb.Init(2.0);
   if(!g_tp.Calculate(g_indicators, g_sym, dummy_bb, entry_price, signal))
   {
      g_log.Debug("TP/SL skipped: R:R below minimum");
      return;
   }

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   double lots = g_scalp_risk.CompressLots(InpZLBaseLots, g_dd_monitor);
   if(lots <= 0) return;

   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, lot_min);

   if(!g_scalp_risk.CanAddLots(lots)) return;

   ENUM_ORDER_TYPE order_type = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, order_type, lots)) return;

   string comment = InpZLTradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
                    + "_TP" + DoubleToString(g_tp.GetTPPoints(g_sym.Point()), 0)
                    + "_SL" + DoubleToString(g_tp.GetSLPoints(g_sym.Point()), 0);

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
                 + " ZLEMA=" + DoubleToString(g_zlema.GetValue(), 2));
   }
}

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
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpZLMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   g_scalp_risk.RecordClose(profit);
   g_log.Info("Closed. P=" + DoubleToString(profit, 2)
              + " Streak=" + IntegerToString(g_scalp_risk.LossStreak()));
}
//+------------------------------------------------------------------+
