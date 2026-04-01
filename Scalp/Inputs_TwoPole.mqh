//+------------------------------------------------------------------+
//| Inputs_TwoPole.mqh                                                |
//| Input parameters for TwoPoleScalp EA                              |
//+------------------------------------------------------------------+
#ifndef INPUTS_TWOPOLE_MQH
#define INPUTS_TWOPOLE_MQH

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpTPSep01 = "=== General Settings ===";   // ──────────────────
input ENUM_SCALP_PROFILE InpTPScalpProfile = SCALP_BALANCED; // Trading profile
input bool    InpTPAllowTrades    = true;                // Allow opening new trades
input ENUM_TRADE_DIR InpTPTradeDir = TRADE_BOTH;         // Trade direction

//+------------------------------------------------------------------+
//| Two-Pole signal settings                                          |
//+------------------------------------------------------------------+
sinput string InpTPSep02 = "=== Two-Pole Signal ===";    // ──────────────────
input int     InpTPFilterLength   = 15;                  // Two-Pole filter length
input int     InpTPEMAPeriod      = 200;                 // EMA trend filter period (M15)
input int     InpTPEMASlopeShift  = 5;                   // EMA slope: bars back for comparison
input double  InpTPVolMult        = 1.2;                 // Volume multiplier (vs avg)
input int     InpTPVolWindow      = 10;                  // Volume average window (bars)

//+------------------------------------------------------------------+
//| RSI confirmation settings                                         |
//+------------------------------------------------------------------+
sinput string InpTPSep02b = "=== RSI Confirmation ===";  // ──────────────────
input int     InpTPRSIPeriod      = 10;                  // RSI period (M5)
input int     InpTPRSIDeviation   = 20;                  // RSI deviation from 50

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpTPSep03 = "=== ATR Settings ===";       // ──────────────────
input int     InpTPATRPeriod      = 14;                  // ATR period (M5)
input int     InpTPATRLongPeriod  = 96;                  // ATR long period (M5)
input double  InpTPATRMinGate     = 0.30;                // Min ATR for trading

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpTPSep04 = "=== TP/SL Settings ===";     // ──────────────────
input double  InpTPTP_ATRMult     = 0.75;                // TP: ATR multiplier
input double  InpTPSL_ATRMult     = 1.50;                // SL: ATR multiplier
input double  InpTPTP_SpreadMult  = 8.0;                 // TP: spread multiplier (fallback)
input double  InpTPSL_SpreadMult  = 6.0;                 // SL: spread multiplier (fallback)
input double  InpTPMinTP_Points   = 30.0;                // Min TP (points)
input double  InpTPMaxTP_Points   = 150.0;               // Max TP (points)
input double  InpTPMinSL_Points   = 40.0;                // Min SL (points)
input double  InpTPMaxSL_Points   = 200.0;               // Max SL (points)
input double  InpTPMinRR          = 0.4;                 // Min risk:reward ratio
input bool    InpTPSmartTP        = false;               // Smart TP (BB middle target)

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpTPSep05 = "=== Breakeven & Trail ===";  // ──────────────────
input double  InpTPBreakevenPct   = 50.0;                // Breakeven trigger (% of TP)
input double  InpTPTrailPct       = 100.0;               // Trail activation (% of TP)
input double  InpTPTrailDistPct   = 40.0;                // Trail distance (% of TP)

//+------------------------------------------------------------------+
//| Time-stop                                                         |
//+------------------------------------------------------------------+
sinput string InpTPSep06 = "=== Time Stop ===";          // ──────────────────
input int     InpTPTimeStopBars   = 5;                   // Close after N M5 bars (0=off)
input int     InpTPMinHoldSec     = 60;                  // Min hold time (seconds)

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpTPSep07 = "=== Lot Sizing ===";         // ──────────────────
input double  InpTPBaseLots       = 0.10;                // Base lot size
input double  InpTPMaxLots        = 0.50;                // Max lot per trade
input double  InpTPMaxExposure    = 1.50;                // Max total exposure (lots)

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpTPSep08 = "=== Risk Management ===";    // ──────────────────
input int     InpTPMaxPerHour     = 10;                  // Max trades per hour
input int     InpTPMaxPerDay      = 50;                  // Max trades per day
input int     InpTPMaxConsecLoss  = 3;                   // Consecutive losses before cooldown
input int     InpTPCooldownSec    = 120;                 // Cooldown seconds after loss streak
input double  InpTPMaxDailyLoss   = 100.0;               // Max daily loss ($)
input int     InpTPMaxSpread      = 40;                  // Max spread (points)

//+------------------------------------------------------------------+
//| Session settings                                                  |
//+------------------------------------------------------------------+
sinput string InpTPSep09 = "=== Session Settings ===";   // ──────────────────
input int     InpTPLondonStart    = 7;                   // London session start (UTC)
input int     InpTPOverlapStart   = 12;                  // London-NY overlap start (UTC)
input int     InpTPOverlapEnd     = 16;                  // London-NY overlap end (UTC)
input int     InpTPNYEnd          = 21;                  // NY session end (UTC)

//+------------------------------------------------------------------+
//| News filter                                                       |
//+------------------------------------------------------------------+
sinput string InpTPSep10 = "=== News Filter ===";        // ──────────────────
input bool    InpTPNewsFilter     = true;                // Enable news filter
input int     InpTPNewsBefore     = 15;                  // Minutes before news
input int     InpTPNewsAfter      = 10;                  // Minutes after news

//+------------------------------------------------------------------+
//| Panel & display                                                   |
//+------------------------------------------------------------------+
sinput string InpTPSep11 = "=== Panel ===";              // ──────────────────
input bool    InpTPShowPanel      = true;                // Show panel
input bool    InpTPDebugMode      = false;               // Debug mode

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpTPSep12 = "=== Identification ===";     // ──────────────────
input int     InpTPMagic          = 84590;               // Magic number
input string  InpTPTradeComment   = "TwoPoleScalp";      // Trade comment

#endif
