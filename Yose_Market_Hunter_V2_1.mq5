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

   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATR);

   if(!ok || a[1]<=0) return;

   double close=iClose(s,InpTimeframe,1);
   double ask=SymbolInfoDouble(s,SYMBOL_ASK);
   double bid=SymbolInfoDouble(s,SYMBOL_BID);

   if(close>f[1] && f[1]>sl[1] && r[1]>=InpRSIBuyLevel)
   {
      double stop=ask-a[1]*InpATRMultiplier;
      double take=ask+(ask-stop)*InpTakeProfitRR;
      double lot=LotSize(s,ask,stop);

      if(lot>0)
         trade.Buy(lot,s,ask,stop,take,"Yose V2.1 BUY");
   }

   if(close<f[1] && f[1]<sl[1] && r[1]<=InpRSISellLevel)
   {
      double stop=bid+a[1]*InpATRMultiplier;
      double take=bid-(stop-bid)*InpTakeProfitRR;
      double lot=LotSize(s,bid,stop);

      if(lot>0)
         trade.Sell(lot,s,bid,stop,take,"Yose V2.1 SELL");
   }
}

double LotSize(string s,double entry,double stop)
{
   if(InpFixedLot>0)
      return NormalizeLot(s,InpFixedLot);

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double risk=balance*InpRiskPercent/100.0;

   double tickSize=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_VALUE);
   double distance=MathAbs(entry-stop);

   if(tickSize<=0 || tickValue<=0 || distance<=0)
      return NormalizeLot(s,0.01);

   double loss=(distance/tickSize)*tickValue;

   if(loss<=0)
      return 0;

   return NormalizeLot(s,risk/loss);
}

double NormalizeLot(string s,double lot)
{
   double min=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
   double max=SymbolInfoDouble(s,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);

   if(step<=0)
      step=min;

   lot=MathMax(min,MathMin(max,lot));
   lot=MathFloor(lot/step)*step;

   return NormalizeDouble(lot,2);
}

int CountPositions(string s)
{
   int n=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(PositionGetString(POSITION_SYMBOL)==s &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
         n++;
   }

   return n;
}
bool SpreadOK(string s)
{
   double ask=SymbolInfoDouble(s,SYMBOL_ASK);
   double bid=SymbolInfoDouble(s,SYMBOL_BID);
   double point=SymbolInfoDouble(s,SYMBOL_POINT);

   if(point<=0) return false;

   return ((ask-bid)/point)<=InpMaxSpreadPoints;
}

bool SessionOK()
{
   if(!InpUseTradingSession) return true;

   MqlDateTime t;
   TimeToStruct(TimeCurrent(),t);

   if(InpSessionStartHour<InpSessionEndHour)
      return t.hour>=InpSessionStartHour &&
             t.hour<InpSessionEndHour;

   return t.hour>=InpSessionStartHour ||
          t.hour<InpSessionEndHour;
}

bool NewsBlocked()
{
   datetime now=TimeTradeServer();

   if(now<=0)
      now=TimeCurrent();

   MqlCalendarValue values[];

   int total=CalendarValueHistory(
      values,
      now-InpNewsMinutesBefore*60,
      now+InpNewsMinutesAfter*60
   );

   if(total<=0)
      return false;

   for(int i=0;i<total;i++)
   {
      MqlCalendarEvent ev;

      if(!CalendarEventById(values[i].event_id,ev))
         continue;

      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH)
         continue;

      string name=ev.name;
      StringToUpper(name);

      if(StringFind(name,"NFP")>=0 ||
         StringFind(name,"NONFARM")>=0 ||
         StringFind(name,"FOMC")>=0 ||
         StringFind(name,"FEDERAL FUNDS")>=0 ||
         StringFind(name,"CPI")>=0 ||
         StringFind(name,"CONSUMER PRICE")>=0 ||
         StringFind(name,"PPI")>=0 ||
         StringFind(name,"PRODUCER PRICE")>=0)
         return true;
   }

   return false;
}

void ManagePositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)
         continue;

      string s=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);

      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double stop=PositionGetDouble(POSITION_SL);
      double take=PositionGetDouble(POSITION_TP);

      if(stop<=0)
         continue;

      double bid=SymbolInfoDouble(s,SYMBOL_BID);
      double ask=SymbolInfoDouble(s,SYMBOL_ASK);
      double price=(type==POSITION_TYPE_BUY)?bid:ask;

      double risk=MathAbs(open-stop);

      if(risk<=0)
         continue;

      double profit=(type==POSITION_TYPE_BUY)?
                    price-open:open-price;

      double rr=profit/risk;

      if(InpUseBreakEven && rr>=InpBreakEvenRR)
      {
         double point=SymbolInfoDouble(s,SYMBOL_POINT);

         double newSL=(type==POSITION_TYPE_BUY)?
            open+InpBreakEvenOffsetPoints*point:
            open-InpBreakEvenOffsetPoints*point;

         if((type==POSITION_TYPE_BUY && newSL>stop) ||
            (type==POSITION_TYPE_SELL && newSL<stop))
            trade.PositionModify(ticket,newSL,take);
      }

      if(InpUseTrailing)
      {
         int h=iATR(s,InpTimeframe,InpATRPeriod);

         if(h==INVALID_HANDLE)
            continue;

         double a[];
         ArraySetAsSeries(a,true);

         if(CopyBuffer(h,0,0,1,a)==1)
         {
            double distance=a[0]*InpTrailingATRMultiplier;

            double newSL=(type==POSITION_TYPE_BUY)?
               price-distance:
               price+distance;

            if((type==POSITION_TYPE_BUY &&
                newSL>stop && newSL<price) ||
               (type==POSITION_TYPE_SELL &&
                newSL<stop && newSL>price))
               trade.PositionModify(ticket,newSL,take);
         }

         IndicatorRelease(h);
      }
   }
}
bool DailyLossReached()
{
   datetime start=StringToTime(
      TimeToString(TimeCurrent(),TIME_DATE)
   );

   if(!HistorySelect(start,TimeCurrent()))
      return false;

   double profit=0;

   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong ticket=HistoryDealGetTicket(i);

      if(ticket==0)
         continue;

      if((ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=InpMagic)
         continue;

      if(HistoryDealGetInteger(ticket,DEAL_ENTRY)==DEAL_ENTRY_OUT)
      {
         profit+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         profit+=HistoryDealGetDouble(ticket,DEAL_SWAP);
         profit+=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      }
   }

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance<=0)
      return false;

   double limit=balance*InpMaxDailyLossPercent/100.0;

   return profit<=-limit;
}

void CloseAllEA()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
         trade.PositionClose(ticket);
   }
}

bool ValidLicense(string key)
{
   if(StringLen(key)<10)
      return false;

   int d=0;

   for(int i=0;i<StringLen(key);i++)
   {
      if(StringGetCharacter(key,i)=='-')
         d++;
   }

   return d>=1;
}
