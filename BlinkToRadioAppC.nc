 #include <Timer.h>
 #include "BlinkToRadio.h"
 
configuration BlinkToRadioAppC {}

implementation {
  components BlinkToRadioC;

  components MainC;
  components LedsC;
  components AMSendReceiveC as Radio;
  components new TimerMilliC() as Timer0;
  
  //New timer to use for resending data when is corrupted or lost
  components new TimerMilliC() as Timer1;

  //Wiring of new Timer component
  BlinkToRadioC.Timer1 -> Timer1;
  
  BlinkToRadioC.Boot -> MainC;
  BlinkToRadioC.RadioControl -> Radio;

  BlinkToRadioC.Leds -> LedsC;
  BlinkToRadioC.Timer0 -> Timer0;

  BlinkToRadioC.Packet -> Radio;
  BlinkToRadioC.AMPacket -> Radio;
  BlinkToRadioC.AMSendReceiveI -> Radio;
}
