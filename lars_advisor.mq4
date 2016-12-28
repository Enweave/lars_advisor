//+------------------------------------------------------------------+

//|                                                 lars_advisor.mq4 |

//|                                      Hydromelallurgist & Enweave |

//|                                             https://www.mql5.com |

//+------------------------------------------------------------------+

#property copyright "Hydromelallurgist & Enweave"

#property link      "https://www.mql5.com"

#property version   "1.01"

#property strict

input int      TimerTime=900; // интервал обновления

input double   TradeValue=0.01; // Размер лота

input double   TradeValueStep=0.01; // Дельта лота на шаг сетки

input double   TradeStep=0.0005; // Делта пунктов

input int      GridSteps=3; // Шагов сетки

extern bool ProfitTrailing=True; // Тралить только профит 

extern int TrailingStop=15; // Фиксированный размер трала 

extern int TrailingStep =2; // Шаг трала 

extern bool UseSound =True; // Использовать звуковой сигнал 

extern string NameFileSound="expert.wav"; // Наименование звукового файла



bool can_make_grid=True;

bool deleting_orders=False;

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

void TrailPosition()

  {

   double pBid,pAsk,pp;



   pp=MarketInfo(OrderSymbol(),MODE_POINT);

   if(OrderType()==OP_BUY)

     {

      pBid=MarketInfo(OrderSymbol(),MODE_BID);

      if(!ProfitTrailing || (pBid-OrderOpenPrice())>TrailingStop*pp)

        {

         if(OrderStopLoss()<pBid-(TrailingStop+TrailingStep-1)*pp)

           {

            ModifyStopLoss(pBid-TrailingStop*pp);

            return;

           }

        }

     }

   if(OrderType()==OP_SELL)

     {

      pAsk=MarketInfo(OrderSymbol(),MODE_ASK);

      if(!ProfitTrailing || OrderOpenPrice()-pAsk>TrailingStop*pp)

        {

         if(OrderStopLoss()>pAsk+(TrailingStop+TrailingStep-1)*pp || OrderStopLoss()==0)

           {

            ModifyStopLoss(pAsk+TrailingStop*pp);

            return;

           }

        }

     }

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

void ModifyStopLoss(double ldStopLoss)

  {

   bool fm;

   fm=OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE);

   if(fm && UseSound) PlaySound(NameFileSound);

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

int OnInit()

  {

   EventSetTimer(TimerTime);

   can_make_grid=True;

   deleting_orders=True;

   Print("Lars_Advisor initialized!");

   return(INIT_SUCCEEDED);

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

  {

   EventKillTimer();

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

int GetMarketOrdersCount()

  {

   int pos=0;

   for(int i=0; i<OrdersTotal(); i++)

     {

      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);

      if(OrderType()==OP_BUY || OrderType()==OP_SELL)

         pos++;

     }

   return(pos);

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+



void DeleteDelayedOrders()

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

  {

   int type,ticket;

   int total=OrdersTotal();



   for(int i=0; i<total; i++)

     {

      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))

        {



         type=OrderType();

         ticket=OrderTicket();

         if(type>1)

           {

            OrderDelete(ticket);

           }

        }

     }

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

double GetProfit()

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

  {

   double profit=0;

   int total=OrdersTotal();



   for(int i=0; i<total; i++)

     {

      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))

        {

         profit+=OrderProfit();

        }



     }

   return profit;

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

void MakeOrder(bool ask,double trade_value,double value)

  {

   int ticket;

   if(ask)

     {

      ticket=OrderSend(Symbol(),2,trade_value,(Ask-value),4,0,0,"My order",16384,0,clrNONE);

      Print("make order, trade_value = ",trade_value," Ask = ",(Ask-value));



        } else {

      ticket=OrderSend(Symbol(),3,trade_value,(Bid+value),4,0,0,"My order",16384,0,clrNONE);

      Print("make order, trade_value = ",trade_value," Bid = ",(Bid+value));

     }

   if(ticket==-1)

     {

      Print("ERROR! ",GetLastError());

     }

  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

void MakeGrid()

  {

   double step_base=TradeStep;

   double trade_base=TradeValue;

   for(int i=0; i<GridSteps; i++)

     {

      MakeOrder(True,trade_base,step_base);

      MakeOrder(False,trade_base,step_base);

      step_base+=TradeStep;

      trade_base+=TradeValueStep;

     }



  }

//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

void OnTimer()

  {

   can_make_grid=True;

   deleting_orders=True;



  }

//+------------------------------------------------------------------+



void OnTick()

  {

   int type,ticket;

   int total=OrdersTotal();

   int total_market=GetMarketOrdersCount();



   if(deleting_orders==True)

     {

      if((total-total_market)>0)

        {

         DeleteDelayedOrders();

           } else {

         deleting_orders=False;

        }

     }



   if((can_make_grid==True) && (deleting_orders==False))

     {

      if((GetProfit()<=0) || (GetMarketOrdersCount()<=(GridSteps*2)))

        {

         MakeGrid();

         can_make_grid=false;

        }

     }



   for(int i=0; i<total; i++)

     {

      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))

        {

         if(OrderSymbol()==Symbol())

           {

            type=OrderType();

            ticket=OrderTicket();



            if(type<2)

              {

               TrailPosition();

              }

           }

        }

     }

  }

//+------------------------------------------------------------------+
