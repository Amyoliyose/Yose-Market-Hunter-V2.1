#property strict
#property version "2.10"
#property description "Yose Market Hunter V2.1"

#include <Trade/Trade.mqh>
CTrade trade;

input string InpSymbols="XAUUSD,BTCUSD";
input ENUM_TIMEFRAMES InpTimeframe=PERIOD_M15;
input ulong InpMagic=210921;

input bool InpAllowNewTrades=false;
input bool InpOneTradePerBar=true;
input int InpMaxPositionsPerSymbol=1;

input double InpRiskPercent=1.0;
input double InpFixedLot=0.0;
input double InpMaxSpreadPoints=1000;

input int InpFastEMA=20;
input int InpSlowEMA=50;
input int InpRSIPeriod=14;
input double InpRSIBuyLevel=55;
input double InpRSISellLevel=45;

input int InpATRPeriod=14;
input double InpATRMultiplier=2.0;
input double InpTakeProfitRR=2.0;

input bool InpUseTradingSession=true;
input int InpSessionStartHour=7;
input int InpSessionEndHour=20;

input bool InpUseNewsFilter=true;
input int InpNewsMinutesBefore=30;
input int InpNewsMinutesAfter=30;

input bool InpUseBreakEven=true;
input double InpBreakEvenRR=1.0;
input double InpBreakEvenOffsetPoints=10;

input bool InpUseTrailing=true;
input double InpTrailingATRMultiplier=1.5;

input bool InpUseDailyLossLimit=true;
input double InpMaxDailyLossPercent=3.0;
input bool InpClosePositionsOnDailyLoss=false;

input bool InpRequireLicense=false;
input string InpLicenseKey="";

string syms[];
datetime lastBar[];

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);

   int n=StringSplit(InpSymbols,',',syms);
   if(n<1) return INIT_FAILED;

   ArrayResize(lastBar,n);

   for(int i=0;i<n;i++)
   {
      StringTrimLeft(syms[i]);
      StringTrimRight(syms[i]);
      SymbolSelect(syms[i],true);
   }

   if(InpRequireLicense && !ValidLicense(InpLicenseKey))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnTick()
{
   ManagePositions();

   if(!InpAllowNewTrades) return;

   if(InpUseDailyLossLimit && DailyLossReached())
   {
      if(InpClosePositionsOnDailyLoss) CloseAllEA();
      return;
   }

   for(int i=0;i<ArraySize(syms);i++)
      ProcessSymbol(syms[i],i);
}

void ProcessSymbol(string s,int index)
{
   if(!SymbolSelect(s,true)) return;
   if(!SessionOK()) return;
   if(InpUseNewsFilter && NewsBlocked()) return;
   if(!SpreadOK(s)) return;
   if(CountPositions(s)>=InpMaxPositionsPerSymbol) return;

   datetime bar=iTime(s,InpTimeframe,0);
   if(bar==0) return;

   if(InpOneTradePerBar && lastBar[index]==bar) return;
   lastBar[index]=bar;

   int hFast=iMA(s,InpTimeframe,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   int hSlow=iMA(s,InpTimeframe,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   int hRSI=iRSI(s,InpTimeframe,InpRSIPeriod,PRICE_CLOSE);
   int hATR=iATR(s,InpTimeframe,InpATRPeriod);

   if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE ||
      hRSI==INVALID_HANDLE || hATR==INVALID_HANDLE) return;

   double f[],sl[],r[],a[];
   ArraySetAsSeries(f,true);
   ArraySetAsSeries(sl,true);
   ArraySetAsSeries(r,true);
   ArraySetAsSeries(a,true);

   bool ok=CopyBuffer(hFast,0,0,2,f)==2 &&
           CopyBuffer(hSlow,0,0,2,sl)==2 &&
           CopyBuffer(hRSI,0,0,2,r)==2 &&
           CopyBuffer(hATR,0,0,2,a)==2;

   Indicator
