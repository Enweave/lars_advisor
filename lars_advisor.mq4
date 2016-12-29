//+------------------------------------------------------------------+
//|                                                 lars_advisor.mq4 |
//|                                      Hydromelallurgist & Enweave |
//|                          https://github.com/Enweave/lars_advisor |
//+------------------------------------------------------------------+

#property copyright "Hydromelallurgist & Enweave"
#property link      "https://github.com/Enweave/lars_advisor"
#property version   "1.02"
#property strict

// grid settings
extern int TimerTime = 900; // интервал обновления
extern double TradeValue = 0.01; // Размер лота
extern double TradeValueStep = 0.01; // Дельта лота на шаг сетки
extern double TradeStep = 0.0005; // Делта пунктов
extern int GridSteps = 3; // Шагов сетки
extern bool EnforcedMode = False; // Усиленный ряжим 

// trail settings
extern bool ProfitTrailing = True; // Тралить только профит 
extern int TrailingStop = 15; // Фиксированный размер трала 
extern int TrailingStep = 2; // Шаг трала 
extern bool UseSound = True; // Использовать звуковой сигнал 
extern string NameFileSound = "expert.wav"; // Наименование звукового файла

// state variables
bool can_make_grid=True;
bool deleting_orders=False;

void TrailPosition() {  
  double pBid,pAsk,pp;

  pp=MarketInfo(OrderSymbol(),MODE_POINT);

  if(OrderType()==OP_BUY) {
    pBid=MarketInfo(OrderSymbol(),MODE_BID);
    
    if(!ProfitTrailing || (pBid-OrderOpenPrice())>TrailingStop*pp) {
      if(OrderStopLoss()<pBid-(TrailingStop+TrailingStep-1)*pp) {
        ModifyStopLoss(pBid-TrailingStop*pp);
        return;
      }
    }
  }

  if(OrderType()==OP_SELL) {
    pAsk=MarketInfo(OrderSymbol(),MODE_ASK);
    
    if(!ProfitTrailing || OrderOpenPrice()-pAsk>TrailingStop*pp) {
      if(OrderStopLoss()>pAsk+(TrailingStop+TrailingStep-1)*pp || OrderStopLoss()==0) {
          ModifyStopLoss(pAsk+TrailingStop*pp);
          return;
      }
    }
  }
}


void ModifyStopLoss(double ldStopLoss) {
  bool fm;

  fm=OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE);
  if(fm && UseSound) PlaySound(NameFileSound);
}


int OnInit() {
  EventSetTimer(TimerTime);

  can_make_grid=True;
  deleting_orders=True;

  Print("Lars_Advisor initialized!");
  PlaySound(NameFileSound);

  return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason) {
  EventKillTimer();
}


int GetMarketOrdersCount() {
  int pos=0;
  
  for(int i=0; i<OrdersTotal(); i++) {
    OrderSelect(i,SELECT_BY_POS,MODE_TRADES);

    if(OrderType()==OP_BUY || OrderType()==OP_SELL) {
      pos++;  
    }
  }

  return(pos);
}


void DeleteDelayedOrders() {
  int type, ticket, total=OrdersTotal();;

  for(int i=0; i<total; i++) {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) {
      type=OrderType();
      ticket=OrderTicket();
      
      if(type>1) {
        OrderDelete(ticket);
      }  

    }
  }
}


double GetProfit() {
  double profit=0;  
  int total=OrdersTotal();

  for(int i=0; i<total; i++) {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) {
      profit+=OrderProfit();
    }
  }

  return profit;
}


void MakeOrder(int order_type,double volume, double price_shift_value) {
  int ticket;
  color order_color;
  double order_price;
  int slippage = 4;
  string log_message = "Making order ";

  switch (order_type) {
    case (2):
      order_price = Ask - price_shift_value;
      order_color = clrDodgerBlue;
      log_message += "<buy limit> ";
      break;

    case (3):
      order_price = Bid + price_shift_value;
      order_color = clrCrimson;
      log_message += "<sell limit> ";
      break;

    case (4):
      order_price = Ask + price_shift_value;
      order_color = clrDodgerBlue;
      log_message += "<buy stop> ";
      break;

    case (5):
      order_price = Bid - price_shift_value;
      order_color = clrCrimson;
      log_message += "<sell stop> ";
      break;
  }

  log_message += "value = " + volume + " price = " + order_price;

  ticket=OrderSend(Symbol(),order_type, volume, order_price, slippage,0,0,"My order",16384,0,order_color);
  if(ticket==-1) {
    log_message += " ...ERROR! " + GetLastError();
  } else {
    log_message += " ...OK!";
  }

  Print(log_message);
}

void MakeGrid() {
  double volume = TradeValue;
  double price_shift_value = TradeStep;
  
  for(int i=0; i<GridSteps; i++) {
    MakeOrder(2,volume, price_shift_value);
    MakeOrder(3,volume, price_shift_value);

    if (EnforcedMode == True) {
      MakeOrder(4,volume, price_shift_value);
      MakeOrder(5,volume, price_shift_value);
    }

    price_shift_value += TradeStep;
    volume += TradeValueStep;
  }
}


void OnTimer() {
  can_make_grid = True;
  deleting_orders = True;
}


void OnTick() {
  int type,ticket;
  int total=OrdersTotal();
  int total_market=GetMarketOrdersCount();

  if(deleting_orders==True) {
    if((total-total_market)>0) {
      DeleteDelayedOrders();
    } else {
      deleting_orders=False;
    }
  }

  if((can_make_grid==True) && (deleting_orders==False)) {
    if((GetProfit()<=0) || (total_market <= (GridSteps*2))) {
      MakeGrid();
      can_make_grid=false;
    }
  }

  for(int i=0; i<total; i++) {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) {
      if(OrderSymbol()==Symbol()) {  
        type=OrderType();
        ticket=OrderTicket();
        if(type<2) {
          TrailPosition();
        }
      }
    }
  }
}