//+------------------------------------------------------------------+
//| Globals_Grid.mqh                                                  |
//| Runtime state variables for WakaGrid EA                           |
//+------------------------------------------------------------------+
#ifndef GLOBALS_GRID_MQH
#define GLOBALS_GRID_MQH

#include "NewBar.mqh"
#include "../Indicators/IndicatorManager.mqh"
#include "../Indicators/RSISignal.mqh"
#include "../Indicators/BollingerCalc.mqh"
#include "../Indicators/ATRVolatility.mqh"
#include "../Grid/MagicNumber.mqh"
#include "../Grid/LotCalculator.mqh"
#include "../Trading/TradeExecutor.mqh"
#include "../Risk/DrawdownMonitor.mqh"
#include "../Risk/MarginCheck.mqh"
#include "../Risk/SpreadFilter.mqh"
#include "../Filters/TimeFilter.mqh"
#include "../Filters/NewsFilter.mqh"
#include "../Utils/SymbolInfo.mqh"
#include "../Utils/Logger.mqh"

//--- Global objects for WakaGrid
CNewBar            g_new_bar;
CIndicatorManager  g_indicators;
CRSISignal         g_rsi_signal;
CBollingerCalc     g_bb_calc;
CATRVolatility     g_atr_vol;
CMagicNumber       g_magic;
CLotCalculator     g_lot_calc;
CTradeExecutor     g_executor;
CDrawdownMonitor   g_dd_monitor;
CMarginCheck       g_margin_check;
CSpreadFilter      g_spread_filter;
CTimeFilter        g_time_filter;
CNewsFilter        g_news_filter;
CSymbolHelper      g_sym;
CLogger            g_log;

#endif
