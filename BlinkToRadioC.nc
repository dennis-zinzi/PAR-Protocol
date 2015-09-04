#include <Timer.h>
#include "BlinkToRadio.h"
 
module BlinkToRadioC {
	uses {
		interface Boot;
		interface SplitControl as RadioControl;

		interface Leds;
		interface Timer<TMilli> as Timer0;
		
		//New Timer to be used for resending data messages
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
	//Boolean to determine if last message has been acknowledged 
	bool isMsgAck = TRUE;
	//Acknowledgment message buffer
	message_t msgAck;
	//Acknowledgment message
	message_t* sendMsgAck = &msgAck;
	//Boolean used to alternate sequence number
	bool isSeqZero = TRUE;
	//Current sequence number
	uint8_t currentSeq = 0;
	
	//Last data message sent
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
		//Check if last data message has been acknowledged
		if(isMsgAck == TRUE){
			BlinkToRadioMsg* btrpkt;

			call AMPacket.setType(sendMsg, AM_BLINKTORADIO);
			call AMPacket.setDestination(sendMsg, DEST_ECHO);
			call AMPacket.setSource(sendMsg, TOS_NODE_ID);
			call Packet.setPayloadLength(sendMsg, sizeof(BlinkToRadioMsg));

			btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(sendMsg, sizeof (BlinkToRadioMsg)));
		
			//Increase couter
			counter++;
			//Message is of data type
			btrpkt->type = TYPE_DATA;
			//If next sequence number is zero assign message 0 sequence number
			if(isSeqZero){
				btrpkt->seq = 0;
				//Next message will have 1 as sequence number
				isSeqZero = FALSE;
			}
			//Else assign sequence number to be 1
			else{
				btrpkt->seq = 1;
				//Next message will have 0 as sequence number
				isSeqZero = TRUE;
			}
			//Current sequence number updated
			currentSeq = btrpkt->seq;
			
			btrpkt->nodeid = TOS_NODE_ID;
			btrpkt->counter = counter;
		
			// send message and store returned pointer to free buffer for next message
			sendMsg = call AMSendReceiveI.send(sendMsg);
		
			//Store last sent message
			lastMsg = sendMsg;
		
			//wait for ack to send next data message
			isMsgAck = FALSE;
			
			//Start timeout Timer
			call Timer1.startOneShot(5000);
			//call Timer1.startOneShot(10000);
			//call Timer1.startOneShot(1000);
		}
	}

	//Timeout timer
	event void Timer1.fired(){
		//If timeout reached and message is yet to be acknowledged, assume lost and send again
		if(isMsgAck == FALSE){
			//Resend last message
			lastMsg = call AMSendReceiveI.send(lastMsg);
			//Restart timeout timer to ensure message sent again in case of new timeout
			call Timer1.startOneShot(5000);
		}
	}
	

	event message_t* AMSendReceiveI.receive(message_t* msg) {
		uint8_t len = call Packet.payloadLength(msg);
		BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(msg, len));
    
    	//Assign LEDs to equal counter
		call Leds.set(btrpkt->counter);
	
		//If message received is of type data
		if(btrpkt->type == TYPE_DATA){
			//Create new acknowledgement message
			BlinkToRadioMsg* ack;
			call AMPacket.setType(sendMsgAck, AM_BLINKTORADIO);
			call AMPacket.setDestination(sendMsgAck, DEST_ECHO);
			call AMPacket.setSource(sendMsgAck, TOS_NODE_ID);
			call Packet.setPayloadLength(sendMsgAck, sizeof(BlinkToRadioMsg));
		
			ack = (BlinkToRadioMsg*)(call Packet.getPayload(sendMsgAck, sizeof (BlinkToRadioMsg)));
			
			//Assign acknowledgement to be of type acknowledgement
			ack->type = TYPE_ACK;
			/*if(isSeqZero){
				ack->seq = 1;
			}
			else{
				ack->seq = 0;
			}*/
			//Set acknowledgement sequence number to correspond to last data message
			ack->seq = btrpkt->seq;
			ack->nodeid = btrpkt->nodeid;
			ack->counter = btrpkt->counter;
		
			//Send acknowledgement message
			sendMsgAck = call AMSendReceiveI.send(sendMsgAck);

		}
	
		//If message received is of type acknowledgement
		else if(btrpkt->type == TYPE_ACK){
			//Check if the acknowledgement message has the correct sequence number
			if(btrpkt->seq == currentSeq){
				//Set last message to be correctly acknowledged
				isMsgAck = TRUE;
			}
		}
		
		return msg; // no need to make msg point to new buffer as msg is no longer needed
	}

}

 
