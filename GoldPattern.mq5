//+------------------------------------------------------------------+
//| GoldPattern.mq5                                                    |
//| Pattern Recognition + Multi-Indicator Confluence EA               |
//| Cosine similarity pattern matching with 6 confluence filters      |
//| Timeframe-selectable: M1/M5/M15                                  |
//+------------------------------------------------------------------+
#property copyright "GoldPattern EA"
#property version   "1.00"
#property strict

//--- Include all modules
#include "GoldEA/Inputs_Pattern.mqh"
#include "GoldEA/Globals_Pattern.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Logger
   g_log.Init("[GoldPat]", InpPDebugMode);
   g_log.Info("Initializing v1.00...");

   //--- Symbol info
   if(!g_sym.Init(_Symbol))
   {
      g_log.Error("Failed to initialize symbol info for " + _Symbol);
      return INIT_FAILED;
   }

   //--- Get TF preset
   TFPreset preset = GetTFPreset(InpPTimeframe);

   //--- Initialize Pattern Engine
   if(!g_engine.Init(_Symbol, InpPTimeframe,
         InpPSTEnable, InpPZLEnable, InpPVWAPEnable,
         InpPStdDevEnable, InpPRSIEnable, InpPVolEnable,
         // Pattern params
         InpPPatternCandles, InpPSimilarity, InpPMinMatches,
         InpPMinAccuracy, InpPLookbackBars, InpPFutureBars,
         InpPUseWicks, InpPMaxMatches,
         // Indicator params
         InpPSTATR, InpPSTMult,
         InpPZLLength, InpPZLBandMult,
         InpPVWAPMinSlope,
         InpPStdDevPeriod, InpPStdDevSMA,
         InpPRSIPeriod, InpPRSIDeviation,
         InpPVolMult, InpPVolWindow,
         InpPATRPeriod, InpPATRMinGate))
   {
      g_log.Error("Failed to initialize Pattern Engine");
      return INIT_FAILED;
   }
   g_engine.SetScoreThreshold(InpPScoreThreshold);

   //--- TP/SL calculator
   double tp_atr = (InpPTP_ATR > 0)    ? InpPTP_ATR    : preset.tp_atr_mult;
   double sl_atr = (InpPSL_ATR > 0)    ? InpPSL_ATR    : preset.sl_atr_mult;
   double tp_sp  = (InpPTP_Spread > 0) ? InpPTP_Spread : preset.tp_spread_mult;
   double sl_sp  = (InpPSL_Spread > 0) ? InpPSL_Spread : preset.sl_spread_mult;

   g_tp.Init(tp_atr, sl_atr, tp_sp, sl_sp,
             InpPMinTP, InpPMaxTP, InpPMinSL, InpPMaxSL,
             InpPMinRR, false);  // No Smart TP (BB middle) for pattern EA

   //--- Trade executor
   g_executor.Init(g_sym, g_log, InpPMagic, 30);

   //--- Position management
   g_pos_mgr.Init(g_executor, g_sym, _Symbol, InpPMagic,
                  InpPBreakevenPct, InpPTrailPct, InpPTrailDistPct,
                  InpPTimeStopBars, InpPMinHoldSec);

   //--- Risk management
   g_risk.Init(_Symbol, InpPMagic,
               InpPMaxPerHour, InpPMaxPerDay,
               InpPMaxConsecLoss, InpPCooldownSec,
               InpPMaxLots, InpPMaxExposure,
               InpPMaxDailyLoss, InpPMinHoldSec);

   //--- Session filter
   g_session.Init(InpPLondonStart, InpPOverlapStart, InpPOverlapEnd, InpPNYEnd,
                  SCALP_BALANCED);

   //--- Spread filter
   g_spread_filter.Init(_Symbol, InpPMaxSpread);

   //--- Margin check
   g_margin_check.Init(0.0);

   //--- News filter
   g_news_filter.Init(InpPNewsFilter, InpPNewsBefore, InpPNewsAfter);

   //--- Drawdown monitor
   g_dd_monitor.Update();

   //--- New bar detector
   g_new_bar.Reset(_Symbol, preset.tf);

   g_log.Info("Initialized on " + _Symbol + " " + EnumToString(preset.tf)
              + " Pattern(" + IntegerToString(preset.pattern_candles) + ")"
              + " Sim>=" + DoubleToString(preset.similarity_threshold, 2)
              + " MinMatch=" + IntegerToString(preset.min_matches)
              + " ScoreThreshold=" + IntegerToString(InpPScoreThreshold)
              + " BaseLot=" + DoubleToString(InpPBaseLots, 2));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_engine.Deinit();
   g_log.Info("Deinitialized. Reason=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Always update DD monitor
   g_dd_monitor.Update();

   //--- Always manage open positions
   g_pos_mgr.ManagePositions();

   //--- SuperTrend trailing (if enabled)
   if(InpPSTTrailing && InpPSTEnable)
      ManageSuperTrendTrail();

   //--- Signal check only on new bar
   if(!g_new_bar.IsNewBar(_Symbol, g_engine.GetPresetTF()))
      return;

   //--- Gate 1: Allow trades
   if(!InpPAllowTrades) return;

   //--- Gate 2: Session
   if(!g_session.CanTrade())
   {
      g_log.Debug("Session blocked");
      return;
   }

   //--- Gate 3: News
   if(!g_news_filter.CanTradeNews()) return;

   //--- Gate 4: Spread
   if(!g_spread_filter.IsSpreadOK())
   {
      g_log.Debug("Spread too wide");
      return;
   }

   //--- Gate 5: Risk throttler
   if(!g_risk.CanTrade()) return;

   //--- Gate 6: Daily loss
   if(g_risk.IsDailyLossBreached()) return;

   //--- Gate 7: Already have position
   if(g_risk.HasOpenPosition()) return;

   //--- Pattern + confluence signal check (most expensive — last)
   SignalScore score = g_engine.CheckSignal();
   int signal = score.direction;

   if(signal == DIR_NONE)
   {
      if(InpPDebugMode)
         g_log.Debug("Signal rejected: " + g_engine.GetRejectReason());
      return;
   }

   //--- Direction filter
   if(InpPTradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpPTradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   //--- Calculate dynamic TP/SL
   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   CIndicatorManager *ind = g_engine.GetIndicators();

   //--- For pattern EA, use a dummy BB calc (TP not BB-dependent)
   CBollingerCalc dummy_bb;
   dummy_bb.Init(2.0);

   if(!g_tp.Calculate(*ind, g_sym, dummy_bb, entry_price, signal))
   {
      g_log.Debug("TP/SL skipped: R:R below minimum");
      return;
   }

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   //--- Fibonacci TP enhancement
   if(InpPFibTP)
   {
      g_engine.UpdateFib();
      CFibLevels *fib = g_engine.GetFib();
      if(fib.IsValid())
      {
         double fib_tp = fib.GetTPTarget(entry_price, signal);
         if(signal == DIR_BUY && fib_tp > tp_price)
            tp_price = fib_tp;
         else if(signal == DIR_SELL && fib_tp < tp_price && fib_tp > 0)
            tp_price = fib_tp;
      }
   }

   //--- Score-based lot sizing
   double base_lots = InpPBaseLots * score.GetLotFactor();

   //--- DD compression
   double lots = g_risk.CompressLots(base_lots, g_dd_monitor);
   if(lots <= 0)
   {
      g_log.Warn("DD hard stop");
      return;
   }

   //--- Normalize lots
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, lot_min);

   //--- Exposure check
   if(!g_risk.CanAddLots(lots)) return;

   //--- Margin check
   ENUM_ORDER_TYPE order_type = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, order_type, lots))
   {
      g_log.Warn("Insufficient margin");
      return;
   }

   //--- Build trade comment with pattern stats
   CPatternMatcher *pm = g_engine.GetPattern();
   string comment = InpPTradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
                    + "_S" + IntegerToString(score.total_score)
                    + "_M" + IntegerToString(pm.GetTotalMatches())
                    + "_C" + DoubleToString(pm.GetConfidence(), 0) + "%";

   //--- Open trade
   bool result = false;
   if(signal == DIR_BUY)
      result = g_executor.OpenBuy(lots, sl_price, tp_price, comment);
   else
      result = g_executor.OpenSell(lots, sl_price, tp_price, comment);

   if(result)
   {
      g_risk.RecordOpen();
      g_log.Info(((signal == DIR_BUY) ? "BUY" : "SELL")
                 + " " + DoubleToString(lots, 2) + " lots"
                 + " " + score.ToString()
                 + " Matches=" + IntegerToString(pm.GetTotalMatches())
                 + " UP=" + DoubleToString(pm.GetUpAccuracy(), 1) + "%"
                 + " DOWN=" + DoubleToString(pm.GetDownAccuracy(), 1) + "%"
                 + " TP=" + DoubleToString(tp_price, (int)g_sym.Digits())
                 + " SL=" + DoubleToString(sl_price, (int)g_sym.Digits()));
   }
   else
   {
      g_log.Warn("Failed to open trade");
   }
}

//+------------------------------------------------------------------+
//| SuperTrend trailing stop management                               |
//+------------------------------------------------------------------+
void ManageSuperTrendTrail()
{
   CSuperTrend *st = g_engine.GetSuperTrend();
   if(!st.IsInitialized()) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpPMagic) continue;

      ulong ticket = PositionGetTicket(i);
      double current_sl = PositionGetDouble(POSITION_SL);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double st_level = g_sym.NormalizePrice(st.GetStopLevel());
      if(st_level <= 0) continue;

      if(type == POSITION_TYPE_BUY)
      {
         if(st_level > open_price && (current_sl == 0 || st_level > current_sl))
            g_executor.ModifyPosition(ticket, st_level, PositionGetDouble(POSITION_TP));
      }
      else
      {
         if(st_level < open_price && (current_sl == 0 || st_level < current_sl))
            g_executor.ModifyPosition(ticket, st_level, PositionGetDouble(POSITION_TP));
      }
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
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpPMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   g_risk.RecordClose(profit);

   g_log.Info("Position closed. Profit=" + DoubleToString(profit, 2)
              + " Streak=" + IntegerToString(g_risk.LossStreak())
              + " Today=" + IntegerToString(g_risk.TradesToday()));
}
//+------------------------------------------------------------------+
