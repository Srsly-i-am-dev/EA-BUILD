//+------------------------------------------------------------------+
//| DIYConfluence.mq5                                                  |
//| Range Filter Confluence EA — multi-indicator swing trading        |
//| Primary: Range Filter direction flip + scored confluence          |
//+------------------------------------------------------------------+
#property copyright "DIYConfluence EA"
#property version   "1.00"
#property strict

#include "DIYStratEA/Inputs_DIY.mqh"
#include "DIYStratEA/Globals_DIY.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
   g_log.Init("[DIYConfluence]", InpDIDebugMode);
   g_log.Info("Initializing v1.00...");

   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to init symbol info");
      return INIT_FAILED;
   }

   if(!g_indicators.Init(_Symbol,
         InpDIRSIPeriod, InpDISignalTF,
         InpDIATRPeriod, InpDISignalTF,
         InpDIATRLongPeriod, InpDISignalTF,
         20, InpDISignalTF,
         21, InpDISignalTF,
         InpDIEMAPeriod, PERIOD_M15))
   {
      g_log.Error("Failed to create indicator handles");
      return INIT_FAILED;
   }

   if(!g_engine.Init(_Symbol, InpDISignalTF,
                     InpDIRangeLength, InpDIRangeQty, InpDIRangeSmoothN,
                     InpDIScoreThreshold))
   {
      g_log.Error("Failed to init DIY engine");
      return INIT_FAILED;
   }
   g_engine.Warmup(500);

   g_tp.Init(InpDITP_ATRMult, InpDISL_ATRMult, 10.0, 6.0,
             InpDIMinTP_Points, InpDIMaxTP_Points,
             InpDIMinSL_Points, InpDIMaxSL_Points,
             InpDIMinRR, false);

   g_executor.Init(g_sym, g_log, InpDIMagic, 30);

   g_scalp_exec.Init(g_executor, g_sym, _Symbol, InpDIMagic,
                     InpDIBreakevenPct, InpDITrailPct, InpDITrailDistPct,
                     0, 0);

   g_scalp_risk.Init(_Symbol, InpDIMagic,
                     100, InpDIMaxPerDay, 5, 300,
                     InpDIMaxLots, InpDIMaxExposure,
                     InpDIMaxDailyLoss, 0);

   g_spread_filter.Init(_Symbol, InpDIMaxSpread);
   g_margin_check.Init(0.0);
   g_dd_monitor.Update();
   g_new_bar.Reset(_Symbol, InpDISignalTF);

   g_log.Info("Initialized. RF(" + IntegerToString(InpDIRangeLength) + ")"
              + " Qty=" + DoubleToString(InpDIRangeQty, 3)
              + " TF=" + EnumToString(InpDISignalTF));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_indicators.Deinit();
   g_engine.Deinit();
   g_log.Info("Deinitialized. Reason=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
void OnTick()
{
   g_dd_monitor.Update();
   g_scalp_exec.ManagePositions();

   if(!g_new_bar.IsNewBar(_Symbol, InpDISignalTF))
      return;

   g_engine.Update(1);

   if(!InpDIAllowTrades) return;
   if(!g_spread_filter.IsSpreadOK()) return;
   if(!g_scalp_risk.CanTrade()) return;
   if(g_scalp_risk.IsDailyLossBreached()) return;
   if(g_scalp_risk.HasOpenPosition()) return;

   int signal = g_engine.CheckSignal(g_indicators, _Symbol, InpDISignalTF);
   if(signal == DIR_NONE)
   {
      if(InpDIDebugMode)
         g_log.Debug("Rejected: " + g_engine.GetRejectReason());
      return;
   }

   if(InpDITradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpDITradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   if(!g_tp.Calculate(g_indicators, g_sym, entry_price, signal))
   {
      g_log.Debug("TP/SL skipped: R:R below minimum");
      return;
   }

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   double lot_factor = g_engine.GetLotFactor();
   double lots = InpDIBaseLots * lot_factor;
   lots = g_scalp_risk.CompressLots(lots, g_dd_monitor);
   if(lots <= 0) return;

   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));

   if(!g_scalp_risk.CanAddLots(lots)) return;

   ENUM_ORDER_TYPE ot = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, ot, lots)) return;

   string comment = InpDITradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
                    + "_S" + IntegerToString(g_engine.GetLastScore());

   bool ok = (signal == DIR_BUY)
      ? g_executor.OpenBuy(lots, sl_price, tp_price, comment)
      : g_executor.OpenSell(lots, sl_price, tp_price, comment);

   if(ok)
   {
      g_scalp_risk.RecordOpen();
      g_log.Info(((signal == DIR_BUY) ? "BUY" : "SELL")
                 + " " + DoubleToString(lots, 2) + "L"
                 + " Score=" + IntegerToString(g_engine.GetLastScore())
                 + " RF=" + DoubleToString(g_engine.GetRFValue(), 2)
                 + " TP=" + DoubleToString(tp_price, (int)g_sym.Digits())
                 + " SL=" + DoubleToString(sl_price, (int)g_sym.Digits()));
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
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpDIMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   g_scalp_risk.RecordClose(profit);
   g_log.Info("Closed. P=" + DoubleToString(profit, 2));
}
//+------------------------------------------------------------------+
