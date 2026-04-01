//+------------------------------------------------------------------+
//| Globals_VIDYA.mqh                                                 |
//| Runtime state variables for VIDYATrend EA                         |
//+------------------------------------------------------------------+
#ifndef GLOBALS_VIDYA_MQH
#define GLOBALS_VIDYA_MQH

#include "../Core/NewBar.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/VIDYACalc.mqh"
#include "../Indicators/SuperTrend.mqh"
#include "../Indicators/ZeroLagEMA.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/ATRVolatility.mqh"
#include "../Trading/TradeExecutor.mqh"
#include "../Risk/DrawdownMonitor.mqh"
#include "../Risk/MarginCheck.mqh"
#include "../Risk/SpreadFilter.mqh"
#include "../Utils/SymbolInfo.mqh"
#include "../Utils/Logger.mqh"
#include "VIDYAEngine.mqh"
#include "../Scalp/ScalpTP.mqh"
#include "../Scalp/ScalpExecutor.mqh"
#include "../Scalp/ScalpRisk.mqh"

//--- Global objects
CNewBar            g_new_bar;
CIndicatorManager  g_indicators;
CTradeExecutor     g_executor;
CDrawdownMonitor   g_dd_monitor;
CMarginCheck       g_margin_check;
CSpreadFilter      g_spread_filter;
CSymbolHelper      g_sym;
CLogger            g_log;

//--- VIDYA-specific modules
CVIDYACalc         g_vidya;
CVIDYAEngine       g_engine;
CScalpTP           g_tp;
CScalpExecutor     g_scalp_exec;
CScalpRisk         g_scalp_risk;

#endif
