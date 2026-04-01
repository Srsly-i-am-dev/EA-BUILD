//+------------------------------------------------------------------+
//| ZeroLagTrend.mq5                                                  |
//| Zero-Lag EMA Trend EA — band breakout swing trading               |
//| Signal: ZLEMA band breakout (trend change) + confluence score     |
//+------------------------------------------------------------------+
#property copyright "ZeroLagTrend EA"
#property version   "1.00"
#property strict

//--- Reuse VIDYATrend EA infrastructure with ZLEMA as primary
#include "Core/Defines.mqh"
#include "Core/NewBar.mqh"
#include "Indicators/IndicatorManager.mqh"
#include "Indicators/ZeroLagEMA.mqh"
#include "Indicators/SuperTrend.mqh"
#include "Indicators/RSISignal.mqh"
#include "Indicators/ATRVolatility.mqh"
#include "Trading/TradeExecutor.mqh"
#include "Risk/DrawdownMonitor.mqh"
#include "Risk/MarginCheck.mqh"
#include "Risk/SpreadFilter.mqh"
#include "Utils/SymbolInfo.mqh"
#include "Utils/Logger.mqh"
#include "Scalp/ScalpTP.mqh"
#include "Scalp/ScalpExecutor.mqh"
#include "Scalp/ScalpRisk.mqh"

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
sinput string InpZTSep01 = "=== General ===";
input bool    InpZTAllowTrades    = true;
input ENUM_TRADE_DIR InpZTTradeDir = TRADE_BOTH;

sinput string InpZTSep02 = "=== ZLEMA Signal ===";
input int     InpZTLength         = 70;                  // ZLEMA length
input double  InpZTBandMult       = 1.2;                 // Band multiplier
input ENUM_TIMEFRAMES InpZTSignalTF = PERIOD_M15;        // Signal timeframe
input int     InpZTScoreThreshold = 60;                  // Min confluence score

sinput string InpZTSep02b = "=== Confluence ===";
input int     InpZTRSIPeriod      = 14;
input int     InpZTEMAPeriod      = 200;

sinput string InpZTSep03 = "=== ATR ===";
input int     InpZTATRPeriod      = 14;
input int     InpZTATRLongPeriod  = 96;

sinput string InpZTSep04 = "=== TP/SL ===";
input double  InpZTTP_ATRMult     = 2.00;
input double  InpZTSL_ATRMult     = 1.00;
input double  InpZTMinTP_Points   = 50.0;
input double  InpZTMaxTP_Points   = 500.0;
input double  InpZTMinSL_Points   = 40.0;
input double  InpZTMaxSL_Points   = 300.0;
input double  InpZTMinRR          = 0.5;

sinput string InpZTSep05 = "=== BE & Trail ===";
input double  InpZTBreakevenPct   = 50.0;
input double  InpZTTrailPct       = 100.0;
input double  InpZTTrailDistPct   = 40.0;

sinput string InpZTSep06 = "=== Lots & Risk ===";
input double  InpZTBaseLots       = 0.10;
input double  InpZTMaxLots        = 0.50;
input double  InpZTMaxExposure    = 2.00;
input int     InpZTMaxPerDay      = 10;
input double  InpZTMaxDailyLoss   = 200.0;
input int     InpZTMaxSpread      = 40;

sinput string InpZTSep07 = "=== ID ===";
input int     InpZTMagic          = 84620;
input string  InpZTTradeComment   = "ZeroLagTrend";
input bool    InpZTDebugMode      = false;

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
CNewBar            g_new_bar;
CIndicatorManager  g_indicators;
CZeroLagEMA        g_zlema;
CSuperTrend        g_supertrend;
CRSISignal         g_rsi;
CATRVolatility     g_atr_vol;
CTradeExecutor     g_executor;
CDrawdownMonitor   g_dd_monitor;
CMarginCheck       g_margin_check;
CSpreadFilter      g_spread_filter;
CSymbolHelper      g_sym;
CLogger            g_log;
CScalpTP           g_tp;
CScalpExecutor     g_scalp_exec;
CScalpRisk         g_scalp_risk;

//--- Track previous ZLEMA direction for detecting flips
int g_prev_zlema_dir = DIR_NONE;

//+------------------------------------------------------------------+
int OnInit()
{
   g_log.Init("[ZeroLagTrend]", InpZTDebugMode);
   g_log.Info("Initializing v1.00...");

   if(!g_sym.Init(_Symbol)) return INIT_FAILED;

   if(!g_indicators.Init(_Symbol,
         InpZTRSIPeriod, InpZTSignalTF,
         InpZTATRPeriod, InpZTSignalTF,
         InpZTATRLongPeriod, InpZTSignalTF,
         20, InpZTSignalTF,
         21, InpZTSignalTF,
         InpZTEMAPeriod, PERIOD_M15))
      return INIT_FAILED;

   if(!g_zlema.Init(_Symbol, InpZTSignalTF, InpZTLength, InpZTBandMult))
      return INIT_FAILED;
   g_zlema.Warmup(300);
   g_prev_zlema_dir = g_zlema.GetDirection();

   if(!g_supertrend.Init(_Symbol, InpZTSignalTF, 10, 3.0))
      return INIT_FAILED;
   g_supertrend.Warmup(300);

   g_rsi.Init(20.0, false);
   g_atr_vol.Init(1.0, 1.5, 0.30);

   g_tp.Init(InpZTTP_ATRMult, InpZTSL_ATRMult, 10.0, 6.0,
             InpZTMinTP_Points, InpZTMaxTP_Points,
             InpZTMinSL_Points, InpZTMaxSL_Points,
             InpZTMinRR, false);

   g_executor.Init(g_sym, g_log, InpZTMagic, 30);
   g_scalp_exec.Init(g_executor, g_sym, _Symbol, InpZTMagic,
                     InpZTBreakevenPct, InpZTTrailPct, InpZTTrailDistPct, 0, 0);
   g_scalp_risk.Init(_Symbol, InpZTMagic, 100, InpZTMaxPerDay,
                     5, 300, InpZTMaxLots, InpZTMaxExposure,
                     InpZTMaxDailyLoss, 0);
   g_spread_filter.Init(_Symbol, InpZTMaxSpread);
   g_margin_check.Init(0.0);
   g_dd_monitor.Update();
   g_new_bar.Reset(_Symbol, InpZTSignalTF);

   g_log.Info("Initialized. ZLEMA(" + IntegerToString(InpZTLength) + ")");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_indicators.Deinit();
   g_zlema.Deinit();
   g_supertrend.Deinit();
}

//+------------------------------------------------------------------+
void OnTick()
{
   g_dd_monitor.Update();
   g_scalp_exec.ManagePositions();

   if(!g_new_bar.IsNewBar(_Symbol, InpZTSignalTF))
      return;

   //--- Update indicators
   g_zlema.Update(1);
   g_supertrend.Update(1);

   if(!InpZTAllowTrades) return;
   if(!g_spread_filter.IsSpreadOK()) return;
   if(!g_scalp_risk.CanTrade()) return;
   if(g_scalp_risk.IsDailyLossBreached()) return;
   if(g_scalp_risk.HasOpenPosition()) return;

   //--- Primary: ZLEMA band breakout (trend change)
   int curr_dir = g_zlema.GetDirection();
   int signal = DIR_NONE;

   if(curr_dir != g_prev_zlema_dir && curr_dir != DIR_NONE)
      signal = curr_dir;

   g_prev_zlema_dir = curr_dir;

   if(signal == DIR_NONE) return;

   //--- Confluence scoring
   int score = 30;  // Primary
   if(g_supertrend.GetDirection() == signal) score += 25;

   double rsi_curr = g_indicators.GetRSI(1);
   double rsi_prev = g_indicators.GetRSI(2);
   int rsi_sig = g_rsi.CheckRecovery(rsi_curr, rsi_prev);
   if(rsi_sig == signal || rsi_sig == DIR_NONE) score += 20;

   if(g_atr_vol.IsMarketActive(g_indicators)) score += 15;

   // Volume check
   long vol_buf[];
   if(CopyTickVolume(_Symbol, InpZTSignalTF, 1, 11, vol_buf) >= 11)
   {
      long cv = vol_buf[10];
      double avg = 0;
      for(int i = 0; i < 10; i++) avg += (double)vol_buf[i];
      avg /= 10;
      if(avg > 0 && (double)cv >= avg * 1.2) score += 10;
   }

   if(score < InpZTScoreThreshold)
   {
      if(InpZTDebugMode)
         g_log.Debug("Score " + IntegerToString(score) + " < " + IntegerToString(InpZTScoreThreshold));
      return;
   }

   if(InpZTTradeDir == TRADE_BUY_ONLY  && signal == DIR_SELL) return;
   if(InpZTTradeDir == TRADE_SELL_ONLY && signal == DIR_BUY)  return;

   //--- TP/SL
   double entry_price = (signal == DIR_BUY) ? g_sym.Ask() : g_sym.Bid();
   if(!g_tp.Calculate(g_indicators, g_sym, entry_price, signal)) return;

   double tp_price = g_tp.GetTPPrice(entry_price, signal);
   double sl_price = g_tp.GetSLPrice(entry_price, signal);

   //--- Lot sizing
   double lot_factor = (score >= 85) ? 1.0 : (score >= 75) ? 0.75 : 0.50;
   double lots = InpZTBaseLots * lot_factor;
   lots = g_scalp_risk.CompressLots(lots, g_dd_monitor);
   if(lots <= 0) return;

   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));

   if(!g_scalp_risk.CanAddLots(lots)) return;

   ENUM_ORDER_TYPE ot = (signal == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!g_margin_check.CanOpenTrade(_Symbol, ot, lots)) return;

   string comment = InpZTTradeComment + "_" + ((signal == DIR_BUY) ? "B" : "S")
                    + "_S" + IntegerToString(score);

   bool ok = (signal == DIR_BUY)
      ? g_executor.OpenBuy(lots, sl_price, tp_price, comment)
      : g_executor.OpenSell(lots, sl_price, tp_price, comment);

   if(ok)
   {
      g_scalp_risk.RecordOpen();
      g_log.Info(((signal == DIR_BUY) ? "BUY" : "SELL")
                 + " " + DoubleToString(lots, 2) + "L"
                 + " Score=" + IntegerToString(score)
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
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpZTMagic) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   g_scalp_risk.RecordClose(profit);
   g_log.Info("Closed. P=" + DoubleToString(profit, 2));
}
//+------------------------------------------------------------------+
