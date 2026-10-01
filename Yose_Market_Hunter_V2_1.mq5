//+------------------------------------------------------------------+
//|                 Yose Market Hunter V2.1                           |
//|                 Automated MT5 Expert Advisor                     |
//+------------------------------------------------------------------+
#property strict
#property version   "2.10"
#property description "Yose Market Hunter V2.1"

#include <Trade/Trade.mqh>

CTrade trade;

//========================= GENERAL SETTINGS =========================
input string           InpSymbols              = "XAUUSD,BTCUSD";
input ENUM_TIMEFRAMES  InpTimeframe             = PERIOD_M15;
input ulong            InpMagic                 = 210921;

input bool             InpAllowNewTrades       = false;
input bool             InpOneTradePerBar       = true;
input int              InpMaxPositionsPerSymbol= 1;

//========================= RISK SETTINGS ============================
input double InpRiskPercent                    = 1.0;
input double InpFixedLot                       = 0.0;
input double InpMaxSpreadPoints                = 1000.0;

//========================= STRATEGY =================================
input int    InpFastEMA                        = 20;
input int    InpSlowEMA                        = 50;
input int    InpRSIPeriod                      = 14;
input double InpRSIBuyLevel                    = 55.0;
input double InpRSISellLevel                   = 45.0;

input int    InpATRPeriod                      = 14;
input double InpATRMultiplier                  = 2.0;
input double InpTakeProfitRR                   = 2.0;

//========================= SESSION ================================
input bool InpUseTradingSession                = true;
input int  InpSessionStartHour                =
