//+------------------------------------------------------------------+
//| Inputs_DIY.mqh                                                    |
//| Input parameters for DIYConfluence EA                             |
//| Implements Range Filter + MA confluence from DIY Custom Strategy  |
//+------------------------------------------------------------------+
#ifndef INPUTS_DIY_MQH
#define INPUTS_DIY_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpDISep01 = "=== General ===";
input bool    InpDIAllowTrades    = true;
input ENUM_TRADE_DIR InpDITradeDir = TRADE_BOTH;

//+------------------------------------------------------------------+
//| Range Filter settings (primary signal)                            |
//+------------------------------------------------------------------+
sinput string InpDISep02 = "=== Range Filter ===";
input int     InpDIRangeLength    = 100;                 // Range filter period
input double  InpDIRangeQty       = 2.618;               // Range size quantity
input int     InpDIRangeSmoothN   = 5;                   // Range smoothing period
input ENUM_TIMEFRAMES InpDISignalTF = PERIOD_M15;        // Signal timeframe

//+------------------------------------------------------------------+
//| Confluence settings                                               |
//+------------------------------------------------------------------+
sinput string InpDISep03 = "=== Confluence ===";
input int     InpDIEMAPeriod      = 200;                 // EMA trend period
input int     InpDIRSIPeriod      = 14;                  // RSI period
input int     InpDIScoreThreshold = 60;                  // Min score to trade

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpDISep04 = "=== ATR ===";
input int     InpDIATRPeriod      = 14;
input int     InpDIATRLongPeriod  = 96;

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpDISep05 = "=== TP/SL ===";
input double  InpDITP_ATRMult     = 2.00;
input double  InpDISL_ATRMult     = 1.00;
input double  InpDIMinTP_Points   = 50.0;
input double  InpDIMaxTP_Points   = 500.0;
input double  InpDIMinSL_Points   = 40.0;
input double  InpDIMaxSL_Points   = 300.0;
input double  InpDIMinRR          = 0.5;

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpDISep06 = "=== BE & Trail ===";
input double  InpDIBreakevenPct   = 50.0;
input double  InpDITrailPct       = 100.0;
input double  InpDITrailDistPct   = 40.0;

//+------------------------------------------------------------------+
//| Lot sizing & Risk                                                 |
//+------------------------------------------------------------------+
sinput string InpDISep07 = "=== Lots & Risk ===";
input double  InpDIBaseLots       = 0.10;
input double  InpDIMaxLots        = 0.50;
input double  InpDIMaxExposure    = 2.00;
input int     InpDIMaxPerDay      = 10;
input double  InpDIMaxDailyLoss   = 200.0;
input int     InpDIMaxSpread      = 40;

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpDISep08 = "=== ID ===";
input int     InpDIMagic          = 84630;
input string  InpDITradeComment   = "DIYConfluence";
input bool    InpDIDebugMode      = false;

#endif
