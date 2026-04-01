//+------------------------------------------------------------------+
//| Defines.mqh                                                       |
//| Shared enums, constants, and macros for WakaGrid + WakaScalp     |
//+------------------------------------------------------------------+
#ifndef DEFINES_MQH
#define DEFINES_MQH

//+------------------------------------------------------------------+
//| Magic number base                                                 |
//+------------------------------------------------------------------+
#define BASE_MAGIC_GRID    84570
#define BASE_MAGIC_SCALP   84580
#define BASE_MAGIC_TWOPOLE 84590
#define BASE_MAGIC_VIDYA   84600
#define BASE_MAGIC_ZEROLAG_S 84610
#define BASE_MAGIC_ZEROLAG_T 84620
#define BASE_MAGIC_DIY     84630

//+------------------------------------------------------------------+
//| Direction constants                                               |
//+------------------------------------------------------------------+
#define DIR_BUY            1
#define DIR_SELL           2
#define DIR_NONE           0

//+------------------------------------------------------------------+
//| Grid lot sizing methods                                           |
//+------------------------------------------------------------------+
enum ENUM_LOT_METHOD
{
   LOT_FIXED          = 0,   // Fixed lot size
   LOT_DEPOSIT_LOAD   = 1,   // Custom deposit load %
   LOT_DYNAMIC        = 2,   // Dynamic (per balance/equity)
   LOT_PRESET_LOW     = 3,   // Low risk (0.25%)
   LOT_PRESET_MED     = 4,   // Medium risk (0.5%)
   LOT_PRESET_SIG     = 5,   // Significant risk (1.0%)
   LOT_PRESET_HIGH    = 6    // High risk (1.5%)
};

//+------------------------------------------------------------------+
//| Drawdown action options                                           |
//+------------------------------------------------------------------+
enum ENUM_DD_ACTION
{
   DD_CLOSE_AND_STOP        = 0,   // Close all + stop trading
   DD_CLOSE_STOP_RESTART    = 1,   // Close all + stop until restart
   DD_STOP_ONLY             = 2,   // Stop new trades only
   DD_PROHIBIT_NEW_GRIDS    = 3,   // Prohibit new grids only
   DD_PROHIBIT_UNTIL_RESTART= 4    // Prohibit until restart
};

//+------------------------------------------------------------------+
//| Trade direction filter                                            |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIR
{
   TRADE_BOTH      = 0,   // Allow buy and sell
   TRADE_BUY_ONLY  = 1,   // Buy only
   TRADE_SELL_ONLY = 2    // Sell only
};

//+------------------------------------------------------------------+
//| Drawdown scope                                                    |
//+------------------------------------------------------------------+
enum ENUM_DD_SCOPE
{
   DD_EA_ONLY       = 0,   // This EA only
   DD_ACCOUNT       = 1    // Entire account
};

//+------------------------------------------------------------------+
//| Trading profile (for WakaScalp)                                   |
//+------------------------------------------------------------------+
enum ENUM_SCALP_PROFILE
{
   SCALP_CONSERVATIVE = 0,   // Conservative (overlap only)
   SCALP_BALANCED     = 1,   // Balanced (London+NY)
   SCALP_ACTIVE       = 2    // Active (extended sessions)
};

//+------------------------------------------------------------------+
//| TP calculation method                                             |
//+------------------------------------------------------------------+
enum ENUM_TP_METHOD
{
   TP_WEIGHTED_AVG  = 0,   // Weighted average price
   TP_SIMPLE_AVG    = 1    // Simple average price
};

//+------------------------------------------------------------------+
//| Lot min/max/step helpers                                          |
//+------------------------------------------------------------------+
#define LOT_MIN_DEFAULT    0.01

#endif
