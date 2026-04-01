//+------------------------------------------------------------------+
//| Globals_Scalp.mqh                                                 |
//| Runtime state variables for WakaScalp EA                          |
//+------------------------------------------------------------------+
#ifndef GLOBALS_SCALP_MQH
#define GLOBALS_SCALP_MQH

#include "../Core/NewBar.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/BollingerCalc.mqh"
#include "../Indicators/ATRVolatility.mqh"
#include "../Trading/TradeExecutor.mqh"
#include "../Risk/DrawdownMonitor.mqh"
#include "../Risk/MarginCheck.mqh"
#include "../Risk/SpreadFilter.mqh"
#include "../Filters/NewsFilter.mqh"
#include "../Utils/SymbolInfo.mqh"
#include "../Utils/Logger.mqh"
#include "ScalpSignal.mqh"
#include "ScalpTP.mqh"
#include "ScalpExecutor.mqh"
#include "ScalpRisk.mqh"
#include "SessionFilter.mqh"

//--- Global objects for WakaScalp
CNewBar            g_new_bar;
CIndicatorManager  g_indicators;
CTradeExecutor     g_executor;
CDrawdownMonitor   g_dd_monitor;
CMarginCheck       g_margin_check;
CSpreadFilter      g_spread_filter;
CNewsFilter        g_news_filter;
CSymbolHelper      g_sym;
CLogger            g_log;

//--- Scalp-specific modules
CScalpSignal       g_signal;
CScalpTP           g_tp;
CScalpExecutor     g_scalp_exec;
CScalpRisk         g_scalp_risk;
CSessionFilter     g_session;

#endif
