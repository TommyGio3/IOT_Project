#include "RadioToss.h"

configuration RadioTossAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, RadioTossC as App;
  //add the other components here
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components ActiveMessageC;
  components RandomC;
  components SerialPrintfC;
  components SerialStartC;
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  
  /****** Wire the other interfaces down here *****/
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.Timer0 -> Timer0;
  App.Timer2 -> Timer2;
  App.Timer1 -> Timer1;
  App.AMControl -> ActiveMessageC;
  App.Packet -> AMSenderC;
  App.Random -> RandomC;
}

