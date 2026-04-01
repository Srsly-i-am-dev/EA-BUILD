//+------------------------------------------------------------------+
//| Inputs_ZeroLag.mqh                                                |
//| Input parameters for ZeroLagScalp EA                              |
//+------------------------------------------------------------------+
#ifndef INPUTS_ZEROLAG_MQH
#define INPUTS_ZEROLAG_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpZLSep01 = "=== General Settings ===";   // ──────────────────
input ENUM_SCALP_PROFILE InpZLScalpProfile = SCALP_BALANCED; // Trading profile
input bool    InpZLAllowTrades    = true;                // Allow opening new trades
input ENUM_TRADE_DIR InpZLTradeDir = TRADE_BOTH;         // Trade direction

//+------------------------------------------------------------------+
//| Zero-Lag signal settings                                          |
//+------------------------------------------------------------------+
sinput string InpZLSep02 = "=== Zero-Lag Signal ===";    // ──────────────────
input int     InpZLEMALength      = 70;                  // ZLEMA length
input double  InpZLBandMult       = 1.2;                 // ZLEMA band multiplier
input int     InpZLTrendEMAPeriod = 200;                 // EMA trend filter period (M15)
input int     InpZLEMASlopeShift  = 5;                   // EMA slope bars
input double  InpZLVolMult        = 1.2;                 // Volume multiplier
input int     InpZLVolWindow      = 10;                  // Volume avg window

//+------------------------------------------------------------------+
//| RSI confirmation settings                                         |
//+------------------------------------------------------------------+
sinput string InpZLSep02b = "=== RSI Confirmation ===";  // ──────────────────
input int     InpZLRSIPeriod      = 10;                  // RSI period (M5)
input int     InpZLRSIDeviation   = 20;                  // RSI deviation from 50

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpZLSep03 = "=== ATR Settings ===";       // ──────────────────
input int     InpZLATRPeriod      = 14;                  // ATR period (M5)
input int     InpZLATRLongPeriod  = 96;                  // ATR long period
input double  InpZLATRMinGate     = 0.30;                // Min ATR for trading

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpZLSep04 = "=== TP/SL Settings ===";     // ──────────────────
input double  InpZLTP_ATRMult     = 1.00;                // TP: ATR multiplier
input double  InpZLSL_ATRMult     = 1.50;                // SL: ATR multiplier
input double  InpZLTP_SpreadMult  = 8.0;                 // TP: spread multiplier
input double  InpZLSL_SpreadMult  = 6.0;                 // SL: spread multiplier
input double  InpZLMinTP_Points   = 30.0;                // Min TP (points)
input double  InpZLMaxTP_Points   = 200.0;               // Max TP (points)
input double  InpZLMinSL_Points   = 40.0;                // Min SL (points)
input double  InpZLMaxSL_Points   = 250.0;               // Max SL (points)
input double  InpZLMinRR          = 0.4;                 // Min risk:reward
input bool    InpZLSmartTP        = false;               // Smart TP

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpZLSep05 = "=== Breakeven & Trail ===";  // ──────────────────
input double  InpZLBreakevenPct   = 50.0;                // Breakeven trigger (% of TP)
input double  InpZLTrailPct       = 100.0;               // Trail activation (% of TP)
input double  InpZLTrailDistPct   = 40.0;                // Trail distance (% of TP)

//+------------------------------------------------------------------+
//| Time-stop                                                         |
//+------------------------------------------------------------------+
sinput string InpZLSep06 = "=== Time Stop ===";          // ──────────────────
input int     InpZLTimeStopBars   = 5;                   // Close after N M5 bars
input int     InpZLMinHoldSec     = 60;                  // Min hold time (sec)

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpZLSep07 = "=== Lot Sizing ===";         // ──────────────────
input double  InpZLBaseLots       = 0.10;                // Base lot size
input double  InpZLMaxLots        = 0.50;                // Max lot per trade
input double  InpZLMaxExposure    = 1.50;                // Max total exposure

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpZLSep08 = "=== Risk Management ===";    // ──────────────────
input int     InpZLMaxPerHour     = 10;                  // Max trades per hour
input int     InpZLMaxPerDay      = 50;                  // Max trades per day
input int     InpZLMaxConsecLoss  = 3;                   // Consecutive losses before cooldown
input int     InpZLCooldownSec    = 120;                 // Cooldown seconds
input double  InpZLMaxDailyLoss   = 100.0;               // Max daily loss ($)
input int     InpZLMaxSpread      = 40;                  // Max spread (points)

//+------------------------------------------------------------------+
//| Session settings                                                  |
//+------------------------------------------------------------------+
sinput string InpZLSep09 = "=== Session Settings ===";   // ──────────────────
input int     InpZLLondonStart    = 7;
input int     InpZLOverlapStart   = 12;
input int     InpZLOverlapEnd     = 16;
input int     InpZLNYEnd          = 21;

//+------------------------------------------------------------------+
//| News filter                                                       |
//+------------------------------------------------------------------+
sinput string InpZLSep10 = "=== News Filter ===";        // ──────────────────
input bool    InpZLNewsFilter     = true;
input int     InpZLNewsBefore     = 15;
input int     InpZLNewsAfter      = 10;

//+------------------------------------------------------------------+
//| Panel & identification                                            |
//+------------------------------------------------------------------+
sinput string InpZLSep11 = "=== Panel ===";              // ──────────────────
input bool    InpZLDebugMode      = false;               // Debug mode
input int     InpZLMagic          = 84610;               // Magic number
input string  InpZLTradeComment   = "ZeroLagScalp";      // Trade comment

#endif
