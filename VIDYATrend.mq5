//+------------------------------------------------------------------+
//| VIDYATrend.mq5                                                    |
//| VIDYA Trend-Following EA — scored confluence swing trading        |
//| Primary: VIDYA trend flip + SuperTrend/ZLEMA/RSI/Vol/ATR score   |
//+------------------------------------------------------------------+
#property copyright "VIDYATrend EA"
#property version   "1.00"
#property strict

#include "VIDYATrendEA/Inputs_VIDYA.mqh"
#include "VIDYATrendEA/Globals_VIDYA.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
   g_log.Init("[VIDYATrend]", InpVDDebugMode);
   g_log.Info("Initializing v1.00...");

   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to init symbol info");
      return INIT_FAILED;
   }

   //--- Core indicators: RSI, ATR short, ATR long, MA, StdDev, EMA(200)
   if(!g_indicators.Init(_Symbol,
         InpVDRSIPeriod,     InpVDSignalTF,
         InpVDATRPeriod,     InpVDSignalTF,
         InpVDATRLongPeriod, InpVDSignalTF,
         20,                 InpVDSignalTF,
         21,                 InpVDSignalTF,
         InpVDEMAPeriod,     PERIOD_M15))
   {
      g_log.Error("Failed to create indicator handles");
      return INIT_FAILED;
   }

   //--- VIDYA indicator
   if(!g_vidya.Init(_Symbol, InpVDSignalTF, InpVDVIDYALength, InpVDMomentum, InpVDBandDist))
   {
      g_log.Error("Failed to init VIDYA");
      return INIT_FAILED;
   }
   g_vidya.Warmup(500);

   //--- Confluence engine
   if(!g_engine.Init(_Symbol, InpVDSignalTF, InpVDScoreThreshold))
   {
      g_log.Error("Failed to init VIDYA engine");
      return INIT_FAILED;
   }
   g_engine.Warmup(500);

   //--- TP/SL
   g_tp.Init(InpVDTP_ATRMult, InpVDSL_ATRMult,
             InpVDTP_SpreadMult, InpVDSL_SpreadMult,
             InpVDMinTP_Points, InpVDMaxTP_Points,
             InpVDMinSL_Points, InpVDMaxSL_Points,
             InpVDMinRR, false);

   //--- Executor
   g_executor.Init(g_sym, g_log, InpVDMagic, 30);

   //--- Position management
   g_scalp_exec.Init(g_executor, g_sym, _Symbol, InpVDMagic,
                     InpVDBreakevenPct, InpVDTrailPct, InpVDTrailDistPct,
                     0, 0);  // No time-stop for swing trades

   //--- Risk (simplified for swing)
   g_scalp_risk.Init(_Symbol, InpVDMagic,
                     100, InpVDMaxPerDay,    // No hourly limit for swing
                     5, 300,                 // Higher tolerance
                     InpVDMaxLots, InpVDMaxExposure,
                     InpVDMaxDailyLoss, 0);

   g_spread_filter.Init(_Symbol, InpVDMaxSpread);
   g_margin_check.Init(0.0);
   g_dd_monitor.Update();
   g_new_bar.Reset(_Symbol, InpVDSignalTF);

   g_log.Info("Initialized on " + _Symbol
              + " TF=" + EnumToString(InpVDSignalTF)
              + " VIDYA(" + IntegerToString(InpVDVIDYALength) + ")"
              + " Threshold=" + IntegerToString(InpVDScoreThreshold));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_indicators.Deinit();
   g_vidya.Deinit();
   g_engine.Deinit();
   g_log.Info("Deinitialized. Reason=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
void OnTick()
{
   g_dd_monitor.Update();
   g_scalp_exec.ManagePositions();

   if(!g_new_bar.IsNewBar(_Symbol, InpVDSignalTF))
      return;

   //--- Update indicators
   g_vidya.Update(1);
   g_engine.Update(1);

   if(!InpVDAllowTrades) return;
   if(!g_spread_filter.IsSpreadOK()) return;
   if(!g_scalp_risk.CanTrade()) return;
   if(g_scalp_risk.IsDailyLossBreached()) return;
   if(g_scalp_risk.HasOpenPosition()) return;

   //--- Scored confluence check
   int signal = g_engine.CheckSignal(g_indicators, g_vidya, _Symbol, InpVDSignalTF);
   if(signal == DIR_NONE)
   {
      if(InpVDDebugMode)
         g_log.Debug("Signal rejected: " + g_engine.GetRejectReason());
      return;
   }

   if(InpVDTradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpVDTradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   //--- TP/SL
   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   if(!g_tp.Calculate(g_indicators, g_sym, entry_price, signal))
   {
      g_log.Debug("TP/SL skipped: R:R below minimum");
      return;
   }

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   //--- Lot sizing (factor from score)
   double lot_factor = g_engine.GetLotFactor();
   double lots = InpVDBaseLots * lot_factor;
   lots = g_scalp_risk.CompressLots(lots, g_dd_monitor);
   if(lots <= 0) return;

   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, lot_min);

   if(!g_scalp_risk.CanAddLots(lots)) return;

   ENUM_ORDER_TYPE order_type = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, order_type, lots)) return;

   string comment = InpVDTradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
                    + "_S" + IntegerToString(g_engine.GetLastScore());

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
                 + " Score=" + IntegerToString(g_engine.GetLastScore())
                 + " VIDYA=" + DoubleToString(g_vidya.GetValue(), 2)
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
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpVDMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   g_scalp_risk.RecordClose(profit);
   g_log.Info("Closed. P=" + DoubleToString(profit, 2));
}
//+------------------------------------------------------------------+
