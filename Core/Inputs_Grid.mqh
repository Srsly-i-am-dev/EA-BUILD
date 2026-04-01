//+------------------------------------------------------------------+
//| Inputs_Grid.mqh                                                   |
//| ALL input parameters for WakaGrid EA — defined upfront            |
//| Avoids breaking .set files when adding features later              |
//+------------------------------------------------------------------+
#ifndef INPUTS_GRID_MQH
#define INPUTS_GRID_MQH

#include "Defines.mqh"

//+------------------------------------------------------------------+
//| General settings                                                  |
//+------------------------------------------------------------------+
sinput string InpSep01 = "=== General Settings ===";  // ──────────────────
input bool    InpAllowNewTrades = true;                // Allow opening new trades
input ENUM_TRADE_DIR InpTradeDirection = TRADE_BOTH;   // Trade direction
input bool    InpReverseStrategy = false;              // Reverse strategy

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
sinput string InpSep02 = "=== Lot Sizing ===";        // ──────────────────
input ENUM_LOT_METHOD InpLotMethod = LOT_PRESET_LOW;   // Lot sizing method
input double  InpFixedLot          = 0.01;             // Fixed lot size
input double  InpDepositLoadPct    = 0.25;             // Custom deposit load (%)
input double  InpDynamicAmount     = 10000.0;          // Dynamic: balance per 0.01 lot
input bool    InpFixedInitDeposit  = false;             // Fixed initial deposit (tester)
input double  InpInitDeposit       = 10000.0;          // Initial deposit amount

//+------------------------------------------------------------------+
//| Martingale multipliers                                            |
//+------------------------------------------------------------------+
sinput string InpSep03 = "=== Grid Multipliers ===";   // ──────────────────
input double  InpMult2nd    = 1.0;                     // 2nd trade multiplier
input double  InpMult3to5   = 2.0;                     // 3rd-5th trade multiplier
input double  InpMult6plus  = 1.6;                     // 6th+ trade multiplier

//+------------------------------------------------------------------+
//| Indicator settings                                                |
//+------------------------------------------------------------------+
sinput string InpSep04 = "=== Indicators ===";         // ──────────────────
input ENUM_TIMEFRAMES InpWorkingTF = PERIOD_M15;       // Working timeframe (BB + RSI)
input int     InpBBPeriod   = 35;                      // Bollinger Band period
input int     InpRSIPeriod  = 20;                      // RSI period
input int     InpRSIValue   = 15;                      // RSI deviation from 50

//+------------------------------------------------------------------+
//| Take profit                                                       |
//+------------------------------------------------------------------+
sinput string InpSep05 = "=== Take Profit ===";        // ──────────────────
input double  InpInitialTP      = 10.0;                // Initial TP (pips)
input bool    InpWeightedTP     = true;                // Use weighted average for TP
input double  InpGridTP         = 0.0;                 // Grid TP (pips, 0=use initial)
input bool    InpSmartTP        = false;               // Smart TP (BB-based)
input double  InpSmartTPPct     = 50.0;                // Smart TP: BB width %
input bool    InpAdjustTPOnNew  = true;                // Adjust TP only on new grid level
input bool    InpCoverSwaps     = false;               // Cover swaps in TP
input bool    InpHideTP         = false;               // Hide TP from broker
input bool    InpOPO_TP         = false;               // OPO method for TP
input ENUM_TIMEFRAMES InpOPO_TF = PERIOD_M15;          // OPO timeframe
input int     InpTPAfterLevel   = 0;                   // Different TP after level (0=off)
input double  InpTPAfterLevelVal= 5.0;                 // TP after level value (pips)
input int     InpTPAfterBars    = 0;                   // Different TP after X bars (0=off)
input double  InpTPAfterBarsVal = 5.0;                 // TP after bars value (pips)

//+------------------------------------------------------------------+
//| Stop loss                                                         |
//+------------------------------------------------------------------+
sinput string InpSep06 = "=== Stop Loss ===";          // ──────────────────
input double  InpStopLoss       = 0.0;                 // Stop loss (pips, 0=1000)
input bool    InpHideSL         = false;               // Hide SL from broker
input bool    InpOPO_SL         = false;               // OPO method for SL
input double  InpTrailingSL     = 0.0;                 // Trailing SL (pips, 0=off)

//+------------------------------------------------------------------+
//| Grid settings                                                     |
//+------------------------------------------------------------------+
sinput string InpSep07 = "=== Grid Settings ===";      // ──────────────────
input double  InpTradeDistance   = 35.0;               // Trade distance (pips)
input bool    InpSmartDistance   = true;                // Smart distance (ATR-based)
input int     InpATRShort       = 96;                  // ATR short period
input int     InpATRLong        = 672;                 // ATR long period
input int     InpMaxGridTrades  = 15;                  // Maximum grid trades
input int     InpGridLevelStart = 1;                   // Grid level to start
input bool    InpKeepOriginal   = false;               // Keep original profit/lot sizing
input bool    InpAllowHedging   = false;               // Allow hedging (buy+sell grid)

//+------------------------------------------------------------------+
//| Risk management                                                   |
//+------------------------------------------------------------------+
sinput string InpSep08 = "=== Risk Management ===";    // ──────────────────
input double  InpMaxSpread      = 30.0;                // Maximum spread (pips)
input double  InpMaxSlippage    = 10.0;                // Maximum slippage (pips)
input double  InpMinFreeMargin  = 100.0;               // Minimum free margin ($)
input double  InpMaxDDPct       = 0.0;                 // Max floating DD (%, 0=off)
input double  InpMaxDDMoney     = 0.0;                 // Max floating DD ($, 0=off)
input ENUM_DD_ACTION InpDDAction = DD_CLOSE_AND_STOP;  // DD action
input ENUM_DD_SCOPE InpDDScope  = DD_EA_ONLY;          // DD scope
input int     InpMaxGridsTotal  = 0;                   // Max grids at a time (0=unlimited)
input int     InpOneSymbolLevel = 0;                   // One symbol if grid reaches level

//+------------------------------------------------------------------+
//| Time settings                                                     |
//+------------------------------------------------------------------+
sinput string InpSep09 = "=== Time Settings ===";      // ──────────────────
input int     InpHourStart      = 0;                   // Hour to start trading
input int     InpHourStop       = 24;                  // Hour to stop trading
input bool    InpTradeMon       = true;                // Trade on Monday
input bool    InpTradeTue       = true;                // Trade on Tuesday
input bool    InpTradeWed       = true;                // Trade on Wednesday
input bool    InpTradeThu       = true;                // Trade on Thursday
input bool    InpTradeFri       = true;                // Trade on Friday
input bool    InpRolloverPause  = true;                // Pause during rollover
input int     InpRolloverStart  = 23;                  // Rollover start hour
input int     InpRolloverStartM = 45;                  // Rollover start minute
input int     InpRolloverEnd    = 0;                   // Rollover end hour
input int     InpRolloverEndM   = 15;                  // Rollover end minute
input bool    InpRemoveSLRoll   = true;                // Remove SL during rollover
input bool    InpRemoveTPRoll   = false;               // Remove TP during rollover
input bool    InpAutoGMT        = true;                // Auto-detect GMT
input int     InpGMTOffset      = 0;                   // Manual GMT offset

//+------------------------------------------------------------------+
//| News filter                                                       |
//+------------------------------------------------------------------+
sinput string InpSep10 = "=== News Filter ===";        // ──────────────────
input bool    InpNewsFilter     = false;               // Enable news filter
input int     InpNewsBefore     = 15;                  // Minutes before news
input int     InpNewsAfter      = 10;                  // Minutes after news
input bool    InpHolidayFilter  = false;               // Disable on bank holidays

//+------------------------------------------------------------------+
//| Panel & display                                                   |
//+------------------------------------------------------------------+
sinput string InpSep11 = "=== Panel ===";              // ──────────────────
input bool    InpShowPanel      = true;                // Show panel
input bool    InpShowStats      = true;                // Show statistics
input bool    InpShowNextLevel  = true;                // Show next grid level
input int     InpFontSize       = 8;                   // Font size
input bool    InpDebugMode      = false;               // Debug mode

//+------------------------------------------------------------------+
//| Identification                                                    |
//+------------------------------------------------------------------+
sinput string InpSep12 = "=== Identification ===";     // ──────────────────
input int     InpMagicBase      = 84570;               // Magic number base
input string  InpTradeComment   = "WakaGrid";          // Trade comment

#endif
