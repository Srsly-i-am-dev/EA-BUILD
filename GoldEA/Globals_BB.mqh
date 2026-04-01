//+------------------------------------------------------------------+
//| Globals_BB.mqh                                                    |
//| Runtime state variables for GoldBB EA                             |
//+------------------------------------------------------------------+
#ifndef GLOBALS_BB_MQH
#define GLOBALS_BB_MQH

#include "../Core/NewBar.mqh"
#include "../Trading/TradeExecutor.mqh"
#include "../Risk/DrawdownMonitor.mqh"
#include "../Risk/MarginCheck.mqh"
#include "../Risk/SpreadFilter.mqh"
#include "../Filters/NewsFilter.mqh"
#include "../Utils/SymbolInfo.mqh"
#include "../Utils/Logger.mqh"
#include "../Scalp/ScalpTP.mqh"
#include "../Scalp/ScalpRisk.mqh"
#include "../Scalp/ScalpExecutor.mqh"
#include "../Scalp/SessionFilter.mqh"
#include "BBEngine.mqh"

//--- Global objects for GoldBB
CNewBar            g_new_bar;
CTradeExecutor     g_executor;
CDrawdownMonitor   g_dd_monitor;
CMarginCheck       g_margin_check;
CSpreadFilter      g_spread_filter;
CNewsFilter        g_news_filter;
CSymbolHelper      g_sym;
CLogger            g_log;

//--- Reused scalp modules
CScalpTP           g_tp;
CScalpRisk         g_risk;
CScalpExecutor     g_pos_mgr;
CSessionFilter     g_session;

//--- BB-specific engine
CBBEngine          g_engine;

#endif
