//+------------------------------------------------------------------+
//| Inputs_Pattern.mqh                                                |
//| All input parameters for GoldPattern EA                           |
//+------------------------------------------------------------------+
#ifndef INPUTS_PATTERN_MQH
#define INPUTS_PATTERN_MQH

#include "../Core/Defines.mqh"
#include "TFPresets.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpPSep01 = "=== General Settings ===";           // ──────────────────
input ENUM_GOLD_TF InpPTimeframe   = GOLD_TF_M5;               // Timeframe preset
input bool    InpPAllowTrades      = true;                      // Allow opening new trades
input ENUM_TRADE_DIR InpPTradeDir  = TRADE_BOTH;                // Trade direction

//+------------------------------------------------------------------+
//| Pattern matching settings                                         |
//+------------------------------------------------------------------+
sinput string InpPSep02 = "=== Pattern Matching ===";           // ──────────────────
input int     InpPPatternCandles   = 0;                         // Pattern candles (0=auto from TF)
input double  InpPSimilarity       = 0;                         // Similarity threshold (0=auto)
input int     InpPMinMatches       = 0;                         // Min matches required (0=auto)
input double  InpPMinAccuracy      = 0;                         // Min accuracy % (0=auto)
input int     InpPLookbackBars     = 0;                         // Lookback bars (0=auto)
input int     InpPFutureBars       = 0;                         // Future bars to check (0=auto)
input bool    InpPUseWicks         = true;                      // Use wick data in pattern
input int     InpPMaxMatches       = 100;                       // Max matches to scan

//+------------------------------------------------------------------+
//| SuperTrend settings                                               |
//+------------------------------------------------------------------+
sinput string InpPSep03 = "=== SuperTrend ===";                 // ──────────────────
input bool    InpPSTEnable         = true;                      // Enable SuperTrend filter
input int     InpPSTATR            = 0;                         // SuperTrend ATR period (0=auto)
input double  InpPSTMult           = 0;                         // SuperTrend multiplier (0=auto)
input bool    InpPSTTrailing       = true;                      // Use SuperTrend as trailing stop

//+------------------------------------------------------------------+
//| Zero-Lag EMA                                                      |
//+------------------------------------------------------------------+
sinput string InpPSep04 = "=== Zero-Lag EMA ===";               // ──────────────────
input bool    InpPZLEnable         = true;                      // Enable ZLEMA trend filter
input int     InpPZLLength         = 0;                         // ZLEMA length (0=auto)
input double  InpPZLBandMult       = 0;                         // ZLEMA band multiplier (0=auto)

//+------------------------------------------------------------------+
//| VWAP                                                              |
//+------------------------------------------------------------------+
sinput string InpPSep05 = "=== VWAP ===";                       // ──────────────────
input bool    InpPVWAPEnable       = true;                      // Enable VWAP bias filter
input double  InpPVWAPMinSlope     = 0;                         // VWAP min slope (0=auto)

//+------------------------------------------------------------------+
//| StdDev Regime                                                     |
//+------------------------------------------------------------------+
sinput string InpPSep06 = "=== Volatility Regime ===";          // ──────────────────
input bool    InpPStdDevEnable     = true;                      // Enable StdDev regime filter
input int     InpPStdDevPeriod     = 0;                         // StdDev period (0=auto)
input int     InpPStdDevSMA        = 0;                         // StdDev SMA period (0=auto)

//+------------------------------------------------------------------+
//| RSI settings                                                      |
//+------------------------------------------------------------------+
sinput string InpPSep07 = "=== RSI ===";                        // ──────────────────
input bool    InpPRSIEnable        = true;                      // Enable RSI confirmation
input int     InpPRSIPeriod        = 0;                         // RSI period (0=auto)
input double  InpPRSIDeviation     = 0;                         // RSI deviation from 50 (0=auto)

//+------------------------------------------------------------------+
//| Volume                                                            |
//+------------------------------------------------------------------+
sinput string InpPSep08 = "=== Volume ===";                     // ──────────────────
input bool    InpPVolEnable        = true;                      // Enable volume confirmation
input double  InpPVolMult          = 0;                         // Volume multiplier (0=auto)
input int     InpPVolWindow        = 0;                         // Volume average window (0=auto)

//+------------------------------------------------------------------+
//| ATR settings                                                      |
//+------------------------------------------------------------------+
sinput string InpPSep09 = "=== ATR ===";                        // ──────────────────
input int     InpPATRPeriod        = 0;                         // ATR period (0=auto)
input double  InpPATRMinGate       = 0;                         // Min ATR for trading (0=auto)

//+------------------------------------------------------------------+
//| TP/SL settings                                                    |
//+------------------------------------------------------------------+
sinput string InpPSep10 = "=== TP/SL ===";                      // ──────────────────
input double  InpPTP_ATR           = 0;                         // TP: ATR multiplier (0=auto)
input double  InpPSL_ATR           = 0;                         // SL: ATR multiplier (0=auto)
input double  InpPTP_Spread        = 0;                         // TP: spread multiplier (0=auto)
input double  InpPSL_Spread        = 0;                         // SL: spread multiplier (0=auto)
input double  InpPMinTP            = 30.0;                      // Min TP (points)
input double  InpPMaxTP            = 200.0;                     // Max TP (points)
input double  InpPMinSL            = 40.0;                      // Min SL (points)
input double  InpPMaxSL            = 250.0;                     // Max SL (points)
input double  InpPMinRR            = 0.4;                       // Min risk:reward ratio
input bool    InpPFibTP            = true;                      // Fibonacci extension TP

//+------------------------------------------------------------------+
//| Fibonacci settings                                                |
//+------------------------------------------------------------------+
sinput string InpPSep11 = "=== Fibonacci ===";                  // ──────────────────
input int     InpPFibLookback      = 0;                         // Fib lookback bars (0=auto)
input int     InpPFibSkip          = 0;                         // Fib skip recent bars (0=auto)

//+------------------------------------------------------------------+
//| Breakeven + trailing                                              |
//+------------------------------------------------------------------+
sinput string InpPSep12 = "=== Breakeven & Trail ===";          // ──────────────────
input double  InpPBreakevenPct     = 50.0;                      // Breakeven trigger (% of TP)
input double  InpPTrailPct         = 100.0;                     // Trail activation (% of TP)
input double  InpPTrailDistPct     = 40.0;                      // Trail distance (% of TP)

//+------------------------------------------------------------------+
//| Time-stop                                                         |
//+------------------------------------------------------------------+
sinput string InpPSep13 = "=== Time Stop ===";                  // ──────────────────
input int     InpPTimeStopBars     = 8;                         // Close after N bars (0=off)
input int     InpPMinHoldSec       = 60;                        // Min hold time (seconds)

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpPSep14 = "=== Lot Sizing ===";                 // ──────────────────
input double  InpPBaseLots         = 0.10;                      // Base lot size
input double  InpPMaxLots          = 0.50;                      // Max lot per trade
input double  InpPMaxExposure      = 1.50;                      // Max total exposure (lots)

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpPSep15 = "=== Risk Management ===";            // ──────────────────
input int     InpPMaxPerHour       = 8;                         // Max trades per hour
input int     InpPMaxPerDay        = 40;                        // Max trades per day
input int     InpPMaxConsecLoss    = 3;                         // Consecutive losses before cooldown
input int     InpPCooldownSec      = 180;                       // Cooldown seconds after loss streak
input double  InpPMaxDailyLoss     = 100.0;                     // Max daily loss ($)
input int     InpPMaxSpread        = 40;                        // Max spread (points)
input int     InpPScoreThreshold   = 65;                        // Min signal score to trade

//+------------------------------------------------------------------+
//| Session + News                                                    |
//+------------------------------------------------------------------+
sinput string InpPSep16 = "=== Session ===";                    // ──────────────────
input int     InpPLondonStart      = 7;                         // London session start (UTC)
input int     InpPOverlapStart     = 12;                        // London-NY overlap start (UTC)
input int     InpPOverlapEnd       = 16;                        // London-NY overlap end (UTC)
input int     InpPNYEnd            = 21;                        // NY session end (UTC)
input bool    InpPNewsFilter       = true;                      // Enable news filter
input int     InpPNewsBefore       = 15;                        // Minutes before high-impact news
input int     InpPNewsAfter        = 10;                        // Minutes after high-impact news

//+------------------------------------------------------------------+
//| Panel & debug                                                     |
//+------------------------------------------------------------------+
sinput string InpPSep17 = "=== Panel ===";                      // ──────────────────
input bool    InpPShowPanel        = true;                      // Show panel
input bool    InpPDebugMode        = false;                     // Debug mode

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpPSep18 = "=== Identification ===";             // ──────────────────
input int     InpPMagic            = 84600;                     // Magic number
input string  InpPTradeComment     = "GoldPat";                 // Trade comment

#endif
