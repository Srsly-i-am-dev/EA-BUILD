//+------------------------------------------------------------------+
//| Inputs_BB.mqh                                                     |
//| All input parameters for GoldBB EA                                |
//+------------------------------------------------------------------+
#ifndef INPUTS_BB_MQH
#define INPUTS_BB_MQH

#include "../Core/Defines.mqh"
#include "TFPresets.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpBBSep01 = "=== General Settings ===";          // ──────────────────
input ENUM_GOLD_TF InpBBTimeframe  = GOLD_TF_M5;               // Timeframe preset
input bool    InpBBAllowTrades     = true;                      // Allow opening new trades
input ENUM_TRADE_DIR InpBBTradeDir = TRADE_BOTH;                // Trade direction

//+------------------------------------------------------------------+
//| Bollinger Band settings                                           |
//+------------------------------------------------------------------+
sinput string InpBBSep02 = "=== Bollinger Bands ===";           // ──────────────────
input int     InpBBPeriod          = 0;                         // BB period (0=auto from TF)
input double  InpBBDeviation       = 0;                         // BB deviation (0=auto)
input bool    InpBBCloseBackInside = true;                      // Close-back-inside mode (vs touch)
input double  InpBBTouchBuffer     = 10.0;                      // Touch buffer (points, touch mode only)

//+------------------------------------------------------------------+
//| SuperTrend settings                                               |
//+------------------------------------------------------------------+
sinput string InpBBSep03 = "=== SuperTrend ===";                // ──────────────────
input int     InpBBSTATR           = 0;                         // SuperTrend ATR period (0=auto)
input double  InpBBSTMult          = 0;                         // SuperTrend multiplier (0=auto)
input bool    InpBBSTTrailing      = true;                      // Use SuperTrend as trailing stop

//+------------------------------------------------------------------+
//| Keltner Channel (squeeze detection)                               |
//+------------------------------------------------------------------+
sinput string InpBBSep04 = "=== Keltner Squeeze ===";           // ──────────────────
input bool    InpBBKCEnable        = true;                      // Enable Keltner squeeze filter
input int     InpBBKCEMA           = 0;                         // KC EMA period (0=auto)
input int     InpBBKCATR           = 0;                         // KC ATR period (0=auto)
input double  InpBBKCMult          = 0;                         // KC multiplier (0=auto)

//+------------------------------------------------------------------+
//| Zero-Lag EMA                                                      |
//+------------------------------------------------------------------+
sinput string InpBBSep05 = "=== Zero-Lag EMA ===";              // ──────────────────
input bool    InpBBZLEnable        = true;                      // Enable ZLEMA trend filter
input int     InpBBZLLength        = 0;                         // ZLEMA length (0=auto)
input double  InpBBZLBandMult      = 0;                         // ZLEMA band multiplier (0=auto)

//+------------------------------------------------------------------+
//| VWAP                                                              |
//+------------------------------------------------------------------+
sinput string InpBBSep06 = "=== VWAP ===";                      // ──────────────────
input bool    InpBBVWAPEnable      = true;                      // Enable VWAP bias filter
input double  InpBBVWAPMinSlope    = 0;                         // VWAP min slope (0=auto)

//+------------------------------------------------------------------+
//| StdDev Regime                                                     |
//+------------------------------------------------------------------+
sinput string InpBBSep07 = "=== Volatility Regime ===";         // ──────────────────
input bool    InpBBStdDevEnable    = true;                      // Enable StdDev regime filter
input int     InpBBStdDevPeriod    = 0;                         // StdDev period (0=auto)
input int     InpBBStdDevSMA       = 0;                         // StdDev SMA period (0=auto)

//+------------------------------------------------------------------+
//| RSI settings                                                      |
//+------------------------------------------------------------------+
sinput string InpBBSep08 = "=== RSI ===";                       // ──────────────────
input bool    InpBBRSIEnable       = true;                      // Enable RSI recovery filter
input int     InpBBRSIPeriod       = 0;                         // RSI period (0=auto)
input double  InpBBRSIDeviation    = 0;                         // RSI deviation from 50 (0=auto)

//+------------------------------------------------------------------+
//| Volume                                                            |
//+------------------------------------------------------------------+
sinput string InpBBSep09 = "=== Volume ===";                    // ──────────────────
input bool    InpBBVolEnable       = true;                      // Enable volume confirmation
input double  InpBBVolMult         = 0;                         // Volume multiplier (0=auto)
input int     InpBBVolWindow       = 0;                         // Volume average window (0=auto)

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpBBSep10 = "=== ATR ===";                       // ──────────────────
input int     InpBBATRPeriod       = 0;                         // ATR period (0=auto)
input double  InpBBATRMinGate      = 0;                         // Min ATR for trading (0=auto)

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpBBSep11 = "=== TP/SL ===";                     // ──────────────────
input double  InpBBTP_ATR          = 0;                         // TP: ATR multiplier (0=auto)
input double  InpBBSL_ATR          = 0;                         // SL: ATR multiplier (0=auto)
input double  InpBBTP_Spread       = 0;                         // TP: spread multiplier (0=auto)
input double  InpBBSL_Spread       = 0;                         // SL: spread multiplier (0=auto)
input double  InpBBMinTP           = 30.0;                      // Min TP (points)
input double  InpBBMaxTP           = 150.0;                     // Max TP (points)
input double  InpBBMinSL           = 40.0;                      // Min SL (points)
input double  InpBBMaxSL           = 200.0;                     // Max SL (points)
input double  InpBBMinRR           = 0.4;                       // Min risk:reward ratio
input bool    InpBBSmartTP         = true;                      // Smart TP (BB middle target)
input bool    InpBBFibTP           = true;                      // Fibonacci extension TP

//+------------------------------------------------------------------+
//| Fibonacci settings                                                |
//+------------------------------------------------------------------+
sinput string InpBBSep12 = "=== Fibonacci ===";                 // ──────────────────
input int     InpBBFibLookback     = 0;                         // Fib lookback bars (0=auto)
input int     InpBBFibSkip         = 0;                         // Fib skip recent bars (0=auto)

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpBBSep13 = "=== Breakeven & Trail ===";         // ──────────────────
input double  InpBBBreakevenPct    = 50.0;                      // Breakeven trigger (% of TP)
input double  InpBBTrailPct        = 100.0;                     // Trail activation (% of TP)
input double  InpBBTrailDistPct    = 40.0;                      // Trail distance (% of TP)

//+------------------------------------------------------------------+
//| Time-stop                                                         |
//+------------------------------------------------------------------+
sinput string InpBBSep14 = "=== Time Stop ===";                 // ──────────────────
input int     InpBBTimeStopBars    = 5;                         // Close after N bars (0=off)
input int     InpBBMinHoldSec      = 60;                        // Min hold time (seconds)

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpBBSep15 = "=== Lot Sizing ===";                // ──────────────────
input double  InpBBBaseLots        = 0.10;                      // Base lot size
input double  InpBBMaxLots         = 0.50;                      // Max lot per trade
input double  InpBBMaxExposure     = 1.50;                      // Max total exposure (lots)

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpBBSep16 = "=== Risk Management ===";           // ──────────────────
input int     InpBBMaxPerHour      = 10;                        // Max trades per hour
input int     InpBBMaxPerDay       = 50;                        // Max trades per day
input int     InpBBMaxConsecLoss   = 3;                         // Consecutive losses before cooldown
input int     InpBBCooldownSec     = 120;                       // Cooldown seconds after loss streak
input double  InpBBMaxDailyLoss    = 100.0;                     // Max daily loss ($)
input int     InpBBMaxSpread       = 40;                        // Max spread (points)
input int     InpBBScoreThreshold  = 65;                        // Min signal score to trade

//+------------------------------------------------------------------+
//| Session + News                                                    |
//+------------------------------------------------------------------+
sinput string InpBBSep17 = "=== Session ===";                   // ──────────────────
input int     InpBBLondonStart     = 7;                         // London session start (UTC)
input int     InpBBOverlapStart    = 12;                        // London-NY overlap start (UTC)
input int     InpBBOverlapEnd      = 16;                        // London-NY overlap end (UTC)
input int     InpBBNYEnd           = 21;                        // NY session end (UTC)
input bool    InpBBNewsFilter      = true;                      // Enable news filter
input int     InpBBNewsBefore      = 15;                        // Minutes before high-impact news
input int     InpBBNewsAfter       = 10;                        // Minutes after high-impact news

//+------------------------------------------------------------------+
//| Panel & debug                                                     |
//+------------------------------------------------------------------+
sinput string InpBBSep18 = "=== Panel ===";                     // ──────────────────
input bool    InpBBShowPanel       = true;                      // Show panel
input bool    InpBBDebugMode       = false;                     // Debug mode

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpBBSep19 = "=== Identification ===";            // ──────────────────
input int     InpBBMagic           = 84590;                     // Magic number
input string  InpBBTradeComment    = "GoldBB";                  // Trade comment

#endif
