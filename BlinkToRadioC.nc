#include <Timer.h>
#include "BlinkToRadio.h"
 
module BlinkToRadioC {
	uses {
		interface Boot;
		interface SplitControl as RadioControl;

		interface Leds;
		interface Timer<TMilli> as Timer0;
		
		interface Timer<TMilli> as Timer1;

		interface Packet;
		interface AMPacket;
		interface AMSendReceiveI;
	}
}

implementation {
	uint16_t counter = 0;
	message_t sendMsgBuf;
	message_t* sendMsg = &sendMsgBuf; // initially points to sendMsgBuf
	bool isMsgAck = TRUE;
	message_t msgAck;
	message_t* sendMsgAck = &msgAck;
	bool isSeqZero = TRUE;
	uint8_t currentSeq = 0;
	
	message_t* lastMsg;

	event void Boot.booted() {
		call RadioControl.start();
	};

	event void RadioControl.startDone(error_t error) {
		if (error == SUCCESS) {
			call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
		}
	};

	event void RadioControl.stopDone(error_t error){};



	event void Timer0.fired() {
		if(isMsgAck == TRUE){
			BlinkToRadioMsg* btrpkt;

			call AMPacket.setType(sendMsg, AM_BLINKTORADIO);
			call AMPacket.setDestination(sendMsg, DEST_ECHO);
			call AMPacket.setSource(sendMsg, TOS_NODE_ID);
			call Packet.setPayloadLength(sendMsg, sizeof(BlinkToRadioMsg));

			btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(sendMsg, sizeof (BlinkToRadioMsg)));
		
			counter++;
			btrpkt->type = TYPE_DATA;
			if(isSeqZero){
				btrpkt->seq = 0;
				isSeqZero = FALSE;
			}
			else{
				btrpkt->seq = 1;
				isSeqZero = TRUE;
			}
			currentSeq = btrpkt->seq;
			btrpkt->nodeid = TOS_NODE_ID;
			btrpkt->counter = counter;
		
			// send message and store returned pointer to free buffer for next message
			sendMsg = call AMSendReceiveI.send(sendMsg);
		
			lastMsg = sendMsg;
		
			//wait for ack to send next data message
			isMsgAck = FALSE;
			
			//call Timer1.startOneShot(10000);
			call Timer1.startOneShot(5000);
			//call Timer1.startOneShot(1000);
		}
	}

	event void Timer1.fired(){
		if(isMsgAck == FALSE){
			lastMsg = call AMSendReceiveI.send(lastMsg);
			call Timer1.startOneShot(5000);
		}
	}
	

	event message_t* AMSendReceiveI.receive(message_t* msg) {
		uint8_t len = call Packet.payloadLength(msg);
		BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(msg, len));
    
		call Leds.set(btrpkt->counter);
	
		if(btrpkt->type == TYPE_DATA){
			BlinkToRadioMsg* ack;
			call AMPacket.setType(sendMsgAck, AM_BLINKTORADIO);
			call AMPacket.setDestination(sendMsgAck, DEST_ECHO);
			call AMPacket.setSource(sendMsgAck, TOS_NODE_ID);
			call Packet.setPayloadLength(sendMsgAck, sizeof(BlinkToRadioMsg));
		
			ack = (BlinkToRadioMsg*)(call Packet.getPayload(sendMsgAck, sizeof (BlinkToRadioMsg)));
			ack->type = TYPE_ACK;
			/*if(isSeqZero){
				ack->seq = 1;
			}
			else{
				ack->seq = 0;
			}*/
			ack->seq = btrpkt->seq;
			ack->nodeid = btrpkt->nodeid;
			ack->counter = btrpkt->counter;
		
			sendMsgAck = call AMSendReceiveI.send(sendMsgAck);

		}
	
		else if(btrpkt->type == TYPE_ACK){
			if(btrpkt->seq == currentSeq){
				isMsgAck = TRUE;
			}
		}
		
		return msg; // no need to make msg point to new buffer as msg is no longer needed
	}

}

 
