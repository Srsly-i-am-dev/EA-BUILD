//+------------------------------------------------------------------+
//| Inputs_VIDYA.mqh                                                  |
//| Input parameters for VIDYATrend EA                                |
//+------------------------------------------------------------------+
#ifndef INPUTS_VIDYA_MQH
#define INPUTS_VIDYA_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpVDSep01 = "=== General Settings ===";   // ──────────────────
input bool    InpVDAllowTrades    = true;                // Allow opening new trades
input ENUM_TRADE_DIR InpVDTradeDir = TRADE_BOTH;         // Trade direction

//+------------------------------------------------------------------+
//| VIDYA signal settings                                             |
//+------------------------------------------------------------------+
sinput string InpVDSep02 = "=== VIDYA Signal ===";       // ──────────────────
input int     InpVDVIDYALength    = 10;                  // VIDYA length
input int     InpVDMomentum       = 20;                  // VIDYA momentum length
input double  InpVDBandDist       = 2.0;                 // Band distance factor
input ENUM_TIMEFRAMES InpVDSignalTF = PERIOD_M15;        // Signal timeframe

//+------------------------------------------------------------------+
//| Confluence settings                                               |
//+------------------------------------------------------------------+
sinput string InpVDSep02b = "=== Confluence ===";        // ──────────────────
input int     InpVDRSIPeriod      = 14;                  // RSI period
input int     InpVDEMAPeriod      = 200;                 // EMA trend period (M15)
input int     InpVDScoreThreshold = 65;                  // Min score to trade

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpVDSep03 = "=== ATR Settings ===";       // ──────────────────
input int     InpVDATRPeriod      = 14;                  // ATR period
input int     InpVDATRLongPeriod  = 96;                  // ATR long period
input double  InpVDATRMinGate     = 0.30;                // Min ATR for trading

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpVDSep04 = "=== TP/SL Settings ===";     // ──────────────────
input double  InpVDTP_ATRMult     = 1.50;                // TP: ATR multiplier
input double  InpVDSL_ATRMult     = 1.00;                // SL: ATR multiplier
input double  InpVDTP_SpreadMult  = 10.0;                // TP: spread multiplier
input double  InpVDSL_SpreadMult  = 6.0;                 // SL: spread multiplier
input double  InpVDMinTP_Points   = 50.0;                // Min TP (points)
input double  InpVDMaxTP_Points   = 500.0;               // Max TP (points)
input double  InpVDMinSL_Points   = 40.0;                // Min SL (points)
input double  InpVDMaxSL_Points   = 300.0;               // Max SL (points)
input double  InpVDMinRR          = 0.5;                 // Min risk:reward

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpVDSep05 = "=== Breakeven & Trail ===";  // ──────────────────
input double  InpVDBreakevenPct   = 50.0;                // Breakeven trigger (% of TP)
input double  InpVDTrailPct       = 100.0;               // Trail activation
input double  InpVDTrailDistPct   = 40.0;                // Trail distance

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpVDSep06 = "=== Lot Sizing ===";         // ──────────────────
input double  InpVDBaseLots       = 0.10;                // Base lot size
input double  InpVDMaxLots        = 0.50;                // Max lot per trade
input double  InpVDMaxExposure    = 2.00;                // Max total exposure

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpVDSep07 = "=== Risk Management ===";    // ──────────────────
input int     InpVDMaxPerDay      = 10;                  // Max trades per day
input double  InpVDMaxDailyLoss   = 200.0;               // Max daily loss ($)
input int     InpVDMaxSpread      = 40;                  // Max spread (points)

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpVDSep08 = "=== Identification ===";     // ──────────────────
input int     InpVDMagic          = 84600;               // Magic number
input string  InpVDTradeComment   = "VIDYATrend";        // Trade comment
input bool    InpVDDebugMode      = false;               // Debug mode

#endif
