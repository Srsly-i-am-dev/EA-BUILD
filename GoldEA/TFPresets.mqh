//+------------------------------------------------------------------+
//| TFPresets.mqh                                                     |
//| Timeframe-based parameter auto-adjustment for GoldPattern/GoldBB |
//| Returns optimized defaults per M1/M5/M15                         |
//+------------------------------------------------------------------+
#ifndef TF_PRESETS_MQH
#define TF_PRESETS_MQH

//+------------------------------------------------------------------+
//| Timeframe selection enum                                          |
//+------------------------------------------------------------------+
enum ENUM_GOLD_TF
{
   GOLD_TF_M1  = 0,   // M1 - Aggressive scalping
   GOLD_TF_M5  = 1,   // M5 - Balanced (recommended)
   GOLD_TF_M15 = 2    // M15 - Swing scalping
};

//+------------------------------------------------------------------+
//| Preset structure for all TF-dependent parameters                  |
//+------------------------------------------------------------------+
struct TFPreset
{
   ENUM_TIMEFRAMES tf;

   //--- Pattern matcher
   int    pattern_candles;
   double similarity_threshold;
   int    min_matches;
   double min_accuracy;
   int    lookback_bars;
   int    future_bars;

   //--- RSI
   int    rsi_period;
   double rsi_deviation;   // distance from 50

   //--- Bollinger Bands
   int    bb_period;
   double bb_deviation;
   bool   bb_close_back_inside;  // false = touch mode for M1

   //--- SuperTrend
   int    st_atr_period;
   double st_multiplier;

   //--- Zero-Lag EMA
   int    zlema_length;
   double zlema_band_mult;

   //--- Keltner Channel
   int    kc_ema_period;
   int    kc_atr_period;
   double kc_multiplier;

   //--- StdDev Regime
   int    stddev_period;
   int    stddev_sma_period;

   //--- Fib Levels
   int    fib_lookback;
   int    fib_skip;

   //--- ATR
   int    atr_period;
   double atr_min_gate;

   //--- TP/SL
   double tp_atr_mult;
   double sl_atr_mult;
   double tp_spread_mult;
   double sl_spread_mult;

   //--- Volume
   double vol_mult;
   int    vol_window;

   //--- VWAP
   double vwap_min_slope;
};

//+------------------------------------------------------------------+
//| Get preset for given timeframe                                    |
//+------------------------------------------------------------------+
TFPreset GetTFPreset(ENUM_GOLD_TF selection)
{
   TFPreset p;
   ZeroMemory(p);

   switch(selection)
   {
      case GOLD_TF_M1:
         p.tf                    = PERIOD_M1;
         p.pattern_candles       = 4;
         p.similarity_threshold  = 0.85;
         p.min_matches           = 8;
         p.min_accuracy          = 62.0;
         p.lookback_bars         = 3000;
         p.future_bars           = 8;
         p.rsi_period            = 7;
         p.rsi_deviation         = 25.0;
         p.bb_period             = 14;
         p.bb_deviation          = 1.8;
         p.bb_close_back_inside  = false;  // touch mode on M1
         p.st_atr_period         = 7;
         p.st_multiplier         = 1.5;
         p.zlema_length          = 50;
         p.zlema_band_mult       = 1.2;
         p.kc_ema_period         = 14;
         p.kc_atr_period         = 7;
         p.kc_multiplier         = 1.5;
         p.stddev_period         = 14;
         p.stddev_sma_period     = 40;
         p.fib_lookback          = 30;
         p.fib_skip              = 2;
         p.atr_period            = 7;
         p.atr_min_gate          = 0.20;
         p.tp_atr_mult           = 0.50;
         p.sl_atr_mult           = 1.00;
         p.tp_spread_mult        = 6.0;
         p.sl_spread_mult        = 5.0;
         p.vol_mult              = 1.3;
         p.vol_window            = 8;
         p.vwap_min_slope        = 0.05;
         break;

      case GOLD_TF_M5:
         p.tf                    = PERIOD_M5;
         p.pattern_candles       = 5;
         p.similarity_threshold  = 0.80;
         p.min_matches           = 10;
         p.min_accuracy          = 60.0;
         p.lookback_bars         = 5000;
         p.future_bars           = 10;
         p.rsi_period            = 10;
         p.rsi_deviation         = 20.0;
         p.bb_period             = 20;
         p.bb_deviation          = 2.0;
         p.bb_close_back_inside  = true;
         p.st_atr_period         = 7;
         p.st_multiplier         = 2.0;
         p.zlema_length          = 70;
         p.zlema_band_mult       = 1.2;
         p.kc_ema_period         = 20;
         p.kc_atr_period         = 10;
         p.kc_multiplier         = 2.0;
         p.stddev_period         = 20;
         p.stddev_sma_period     = 50;
         p.fib_lookback          = 50;
         p.fib_skip              = 3;
         p.atr_period            = 14;
         p.atr_min_gate          = 0.30;
         p.tp_atr_mult           = 0.75;
         p.sl_atr_mult           = 1.50;
         p.tp_spread_mult        = 8.0;
         p.sl_spread_mult        = 6.0;
         p.vol_mult              = 1.2;
         p.vol_window            = 10;
         p.vwap_min_slope        = 0.10;
         break;

      case GOLD_TF_M15:
         p.tf                    = PERIOD_M15;
         p.pattern_candles       = 8;
         p.similarity_threshold  = 0.78;
         p.min_matches           = 12;
         p.min_accuracy          = 58.0;
         p.lookback_bars         = 5000;
         p.future_bars           = 12;
         p.rsi_period            = 14;
         p.rsi_deviation         = 15.0;
         p.bb_period             = 20;
         p.bb_deviation          = 2.2;
         p.bb_close_back_inside  = true;
         p.st_atr_period         = 10;
         p.st_multiplier         = 2.5;
         p.zlema_length          = 100;
         p.zlema_band_mult       = 1.3;
         p.kc_ema_period         = 20;
         p.kc_atr_period         = 14;
         p.kc_multiplier         = 2.5;
         p.stddev_period         = 20;
         p.stddev_sma_period     = 50;
         p.fib_lookback          = 80;
         p.fib_skip              = 5;
         p.atr_period            = 14;
         p.atr_min_gate          = 0.40;
         p.tp_atr_mult           = 1.00;
         p.sl_atr_mult           = 2.00;
         p.tp_spread_mult        = 10.0;
         p.sl_spread_mult        = 8.0;
         p.vol_mult              = 1.1;
         p.vol_window            = 12;
         p.vwap_min_slope        = 0.15;
         break;
   }

   return p;
}

#endif
