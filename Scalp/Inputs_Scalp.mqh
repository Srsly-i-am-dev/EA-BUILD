//+------------------------------------------------------------------+
//| Inputs_Scalp.mqh                                                  |
//| ALL input parameters for WakaScalp EA — defined upfront           |
//+------------------------------------------------------------------+
#ifndef INPUTS_SCALP_MQH
#define INPUTS_SCALP_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpSSep01 = "=== General Settings ===";   // ──────────────────
input ENUM_SCALP_PROFILE InpScalpProfile = SCALP_BALANCED; // Trading profile
input bool    InpSAllowTrades    = true;                // Allow opening new trades
input ENUM_TRADE_DIR InpSTradeDir = TRADE_BOTH;         // Trade direction

//+------------------------------------------------------------------+
//| Signal settings                                                   |
//+------------------------------------------------------------------+
sinput string InpSSep02 = "=== Signal Settings ===";    // ──────────────────
input int     InpSRSIPeriod      = 10;                  // RSI period (M5)
input int     InpSRSIDeviation   = 20;                  // RSI deviation from 50 (30/70)
input int     InpSBBPeriod       = 20;                  // BB MA period (M5)
input double  InpSBBDeviation    = 2.0;                 // BB standard deviation multiplier
input int     InpSEMAPeriod      = 200;                 // EMA trend filter period (M15)
input int     InpSEMASlopeShift  = 5;                   // EMA slope: bars back for comparison
input double  InpSVolMult        = 1.2;                 // Volume multiplier (vs 10-bar avg)
input int     InpSVolWindow      = 10;                  // Volume average window (bars)
input double  InpSSqueezeThresh  = 0.5;                 // BB squeeze threshold (% of ATR)

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpSSep03 = "=== ATR Settings ===";       // ──────────────────
input int     InpSATRPeriod      = 14;                  // ATR period (M5)
input int     InpSATRLongPeriod  = 96;                  // ATR long period (M5, for squeeze)
input double  InpSATRMinGate     = 0.30;                // Min ATR for trading (price units)

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpSSep04 = "=== TP/SL Settings ===";     // ──────────────────
input double  InpSTP_ATRMult     = 0.75;                // TP: ATR multiplier
input double  InpSSL_ATRMult     = 1.50;                // SL: ATR multiplier
input double  InpSTP_SpreadMult  = 8.0;                 // TP: spread multiplier (fallback)
input double  InpSSL_SpreadMult  = 6.0;                 // SL: spread multiplier (fallback)
input double  InpSMinTP_Points   = 30.0;                // Min TP (points)
input double  InpSMaxTP_Points   = 150.0;               // Max TP (points)
input double  InpSMinSL_Points   = 40.0;                // Min SL (points)
input double  InpSMaxSL_Points   = 200.0;               // Max SL (points)
input double  InpSMinRR          = 0.4;                 // Min risk:reward ratio
input bool    InpSSmartTP        = true;                // Smart TP (BB middle target)

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpSSep05 = "=== Breakeven & Trail ===";  // ──────────────────
input double  InpSBreakevenPct   = 50.0;                // Breakeven trigger (% of TP distance)
input double  InpSTrailPct       = 100.0;               // Trail activation (% of TP distance)
input double  InpSTrailDistPct   = 40.0;                // Trail distance (% of TP distance)

//+------------------------------------------------------------------+
//| Time-stop                                                         |
//+------------------------------------------------------------------+
sinput string InpSSep06 = "=== Time Stop ===";          // ──────────────────
input int     InpSTimeStopBars   = 5;                   // Close after N M5 bars (0=off)
input int     InpSMinHoldSec     = 60;                  // Min hold time (seconds)

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpSSep07 = "=== Lot Sizing ===";         // ──────────────────
input double  InpSBaseLots       = 0.10;                // Base lot size
input double  InpSMaxLots        = 0.50;                // Max lot per trade
input double  InpSMaxExposure    = 1.50;                // Max total exposure (lots)

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpSSep08 = "=== Risk Management ===";    // ──────────────────
input int     InpSMaxPerHour     = 10;                  // Max trades per hour
input int     InpSMaxPerDay      = 50;                  // Max trades per day
input int     InpSMaxConsecLoss  = 3;                   // Consecutive losses before cooldown
input int     InpSCooldownSec    = 120;                 // Cooldown seconds after loss streak
input double  InpSMaxDailyLoss   = 100.0;               // Max daily loss ($)
input int     InpSMaxSpread      = 40;                  // Max spread (points)

//+------------------------------------------------------------------+
//| Session settings                                                  |
//+------------------------------------------------------------------+
sinput string InpSSep09 = "=== Session Settings ===";   // ──────────────────
input int     InpSLondonStart    = 7;                   // London session start (UTC)
input int     InpSOverlapStart   = 12;                  // London-NY overlap start (UTC)
input int     InpSOverlapEnd     = 16;                  // London-NY overlap end (UTC)
input int     InpSNYEnd          = 21;                  // NY session end (UTC)

//+------------------------------------------------------------------+
//| News filter                                                       |
//+------------------------------------------------------------------+
sinput string InpSSep10 = "=== News Filter ===";        // ──────────────────
input bool    InpSNewsFilter     = true;                // Enable news filter
input int     InpSNewsBefore     = 15;                  // Minutes before high-impact news
input int     InpSNewsAfter      = 10;                  // Minutes after high-impact news

//+------------------------------------------------------------------+
//| Panel & display                                                   |
//+------------------------------------------------------------------+
sinput string InpSSep11 = "=== Panel ===";              // ──────────────────
input bool    InpSShowPanel      = true;                // Show panel
input int     InpSFontSize       = 8;                   // Font size
input bool    InpSDebugMode      = false;               // Debug mode

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpSSep12 = "=== Identification ===";     // ──────────────────
input int     InpSMagic          = 84580;               // Magic number
input string  InpSTradeComment   = "WakaScalp";         // Trade comment

#endif
