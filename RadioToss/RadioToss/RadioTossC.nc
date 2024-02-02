#include "Timer.h"
#include "RadioToss.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "printf.h"

//pan routing table
typedef struct pan_routing_table {
	uint16_t nodeID;
	uint16_t topic;
	uint16_t connect;// boolean var that says if a node is connected to the pan
} pan_routing_table;
//struct used to forward the pub message to the subscribers
typedef struct ObjectToNode {
    uint16_t dest;
	uint8_t topic;
	uint16_t payload;
	struct ObjectToNode* next;
}ObjectToNode;

//struct used to forward the pub message to node-red
typedef struct ObjectToNodeRed {
    uint16_t topic;
	uint16_t payload;
    struct ObjectToNodeRed* next;
}ObjectToNodeRed;



module RadioTossC @safe() {
  uses {
    /****** INTERFACES *****/
	interface Boot;
    //interfaces for communication
    interface Receive;
    interface AMSend;
    interface Packet;
    interface SplitControl as AMControl;
	//interface for timers
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;
	interface Timer<TMilli> as Timer2;
    //other interfaces, if needed
    interface Random;
  }
}
implementation {

  message_t globalPacket;
  ObjectToNodeRed* objectList = NULL;
  ObjectToNode* objectListToNode=NULL;
  pan_routing_table table[8];
  uint8_t randPubTopic;//topic upon which a node publish
  uint16_t randTopic[]={0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1 , 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1 ,2};
  uint16_t timeToPub;//time upon which a node publish
  bool flagConnect, flagSub;
  bool locked;
  
  // Initialize the routing table
  void initializeRoutingTable(){
	 uint8_t i;
	 for(i=0; i<8; i++){
		table[i].nodeID = 0;
		table[i].connect = 0;
		table[i].topic = 10;
		}
  }
    
  //function that adds connect to pan routing table
  void addingConToRoutingTable(radio_msg_t* message){
  	  table[message->sender-1].nodeID = message->sender;
      table[message->sender-1].connect = 1;
  }
  // Function that adds subscription to pan routing table
  void addingSubToRoutingTable(radio_msg_t* message){
	  if(table[message->sender-1].topic == 10) {
		  table[message->sender-1].topic = message->topic;
	  	}
  }  
  //Function that sends a connect message to the panc
  void sendConnect (){
  	radio_msg_t* packet_to_send = (radio_msg_t*)call Packet.getPayload(&globalPacket, sizeof(radio_msg_t));
  	if( !flagConnect){
      	packet_to_send->type=0;
	    packet_to_send->sender=TOS_NODE_ID;
	    packet_to_send->destination=9;
	    packet_to_send->acked=0;
	//dbg("radio_send","Connect packet %d %d %d %d \n",packet_to_send->type ,packet_to_send->sender,packet_to_send->destination, packet_to_send->acked);
	
	    if (call AMSend.send(9, &globalPacket, sizeof(radio_msg_t)) == SUCCESS) {
		   // dbg("radio_send", "Sending Connect packet....\n");	
		    locked = TRUE;
	    }
        call Timer0.startOneShot(100);
	}
  }
  //Function that sends a subscription message to the panc
  void sendSub (){
  	radio_msg_t* packet_to_send = (radio_msg_t*)call Packet.getPayload(&globalPacket, sizeof(radio_msg_t));
  	if( !flagSub){
      	packet_to_send->type=2;
		//dbg("radio_send", "flagConnect :%d ....message->acked: %d \n",flagConnect,message->acked);
		packet_to_send->sender=TOS_NODE_ID;
		packet_to_send->destination=9;
		packet_to_send->topic= randTopic[call Random.rand32()%24];
		dbg("radio_send", "I'm node %d and I subscribe on  topic %d...\n",TOS_NODE_ID,packet_to_send->topic);	
				
		if (call AMSend.send(9, &globalPacket, sizeof(radio_msg_t)) == SUCCESS) {
           // dbg("radio_send", "Sending SUB packet....\n");	
            locked = TRUE;
        }call Timer0.startOneShot(100);
	}
  }
 event void Timer0.fired() {
  	/* Timer triggered to perform the ritrasmission phase of connect and subscription and the pub phase of the node toward the panC*/  	  	 	
  	if(!flagConnect){
        sendConnect ();
  	}else{
  	    if(!flagSub)sendSub();
  	    if(locked) {
            return;
        }else 
        {
            radio_msg_t* rcm = (radio_msg_t*)call Packet.getPayload(&globalPacket, sizeof(radio_msg_t));
            if (rcm == NULL) {
	            return;
            }
            rcm-> type=4;
            rcm->sender = TOS_NODE_ID;
            rcm->destination=9;
            rcm-> topic=randPubTopic;
            rcm-> payload= call Random.rand16()%500;
          
            if (call AMSend.send(9, &globalPacket, sizeof(radio_msg_t)) == SUCCESS) {
            
               locked = TRUE;
            }  	
         } 
    }
 }	
 //adding the pubmessage received from the node in a list with only two field to forward to nodered
 void addObjectToSendToNodeRed(uint16_t topic, uint16_t payload) {
    ObjectToNodeRed* newObject = (ObjectToNodeRed*)malloc(sizeof(ObjectToNodeRed));
    newObject->topic = topic;
    newObject-> payload= payload;
    newObject->next = NULL;
    
    dbg("radio", "Topic : %d ------Payload: %d.\n",newObject->nodeRed.topic,newObject->nodeRed.payload);
    if (objectList == NULL) {
        objectList = newObject;
    } else {
        ObjectToNodeRed* currentObject = objectList;
        while (currentObject->next != NULL) {
            currentObject = currentObject->next;
        }
        currentObject->next = newObject;
    }
 }

//adding the pubmessage received from the node  
 void addObjectToSendToNode(uint16_t dest,uint16_t topic,uint16_t payload) {
    ObjectToNode* newObject = (ObjectToNode*)malloc(sizeof(ObjectToNode));
    newObject->dest =dest;
    newObject->topic= topic;
    newObject-> payload= payload;
    newObject->next = NULL;

    if (objectListToNode == NULL) {
        objectListToNode = newObject;
    } else {
        ObjectToNode* currentObject = objectListToNode;
        while (currentObject->next != NULL) {
            currentObject = currentObject->next;
        }
        currentObject->next = newObject;
    }
}

/*
// solo per vedere la lista dei messagi da rinviare ai subs
 void accessObjectsNode() {
    ObjectToNode* currentObject = objectListToNode;
    //ObjectToNodeRed* nextObject=NULL;
    while (currentObject != NULL) {
        dbg("radio","NOdi:Sono nella lista -> Payload: %d...Topic: %d...Dest: %d\n",currentObject->payload,currentObject->topic,currentObject->dest);
        currentObject = currentObject->next;
        
    }
 }
// solo per vedere la lista dei messagi da rinviare ai nodered
 void accessObjects() {
    ObjectToNodeRed* currentObject = objectList;
    //ObjectToNodeRed* nextObject=NULL;
    while (currentObject != NULL) {
        dbg("radio","Sono nella lista -> Payload: %d...Topic: %d\n",currentObject->nodeRed.payload,currentObject->nodeRed.topic);
        currentObject = currentObject->next;
       
    }
 }*/
 
 /*Implementation of the logic to perform the actual send of the packet toward the subscribers from the panc */
 bool actual_send_to_node(ObjectToNode* currentObject){
	radio_msg_t* packet_to_send = (radio_msg_t*)call Packet.getPayload(&globalPacket, sizeof(radio_msg_t));
        
    if(locked == TRUE){ 	
		dbg("radio_send", "Already sending a message\n");
	}else{
        if(currentObject != NULL){
            packet_to_send-> type=4;
            packet_to_send->sender = 9;
            packet_to_send->destination=currentObject->dest;
            packet_to_send-> topic=currentObject->topic;
            packet_to_send-> payload= currentObject->payload;
           
            if (call AMSend.send(currentObject->dest, &globalPacket, sizeof(radio_msg_t)) == SUCCESS) {
                dbg("radio_send", "inoltro di un pub message ai nodi subscriber...\n ");	
                locked = TRUE;
		    } 
         }    
     }
 }  	
 event void Timer1.fired() {
	/* Timer triggered to perform the panc's forwarding of publish message to the subscriber */
	ObjectToNode* currentObject = objectListToNode;
    if(currentObject!= NULL){
          actual_send_to_node(currentObject);
          objectListToNode=currentObject->next;
    }
    //TODO da decommentare se si vuole vedere l'evoluzione della lista insieme alla funzione che è sopra
   	//accessObjectsNode();
 }
 
 
 /*Implement here the logic to perform the actual send of the packet toward node-red */
 bool actual_send_to_node_red (ObjectToNodeRed* currentObject){
    if(currentObject != NULL){
        //dbg("radio", "Topic : %d ------Payload: %d.\n",currentObject->nodeRed.topic,currentObject->nodeRed.payload);
        printf("%d,%d\n",currentObject->topic,currentObject->payload);      
  	    printfflush();
    }	
 }
 event void Timer2.fired() {
	/* Timer triggered to perform the panc's forwarding of publish message to node-red */
	
	ObjectToNodeRed* currentObject = objectList;
    if(currentObject!= NULL){
          actual_send_to_node_red (currentObject);
          objectList=currentObject->next;
    }
 }
  

 
 event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	/* Parse the receive packet*/
	bool isPresent = FALSE;
	uint8_t i; 
    radio_msg_t* packet_to_send = (radio_msg_t*)call Packet.getPayload(&globalPacket, sizeof(radio_msg_t));
	radio_msg_t* message = (radio_msg_t*)payload;
	
    
    if (len != sizeof(radio_msg_t)) {return bufPtr;} //If the message isn't what we expect we do nothing
	else{
    	   	
    	//If I am the PANC
    	if (TOS_NODE_ID == 9){
            //received a connect message      
			if(message->type == 0  ){ // Adding to my routing table
			
					addingConToRoutingTable(message);
					//send the CONNACK
					packet_to_send->type=1;
					packet_to_send->sender=TOS_NODE_ID;
					packet_to_send->destination=message->sender;
					packet_to_send->acked=1;
					if (call AMSend.send(message->sender, &globalPacket, sizeof(radio_msg_t)) == SUCCESS) {
		               // dbg("radio_send", "Sending ConnACK packet to %d ....\n", packet_to_send->destination);	
		                locked = TRUE;
	                }
					
			}//received a subsciption message
			else if(message->type == 2){	
			        if(message->sender == table[message->sender-1].nodeID && table[message->sender-1].connect == 1){
						//Update routing table with the topic
						addingSubToRoutingTable(message);
						for(i=0; i<8;i++)dbg("radio","Routing table %d:%d %d\n",table[i].nodeID ,table[i].topic, table[i].connect);
						//dbg("radio_send", "Sono nel suBack ....%d\n",message->sender);	
						//send the SUBACK
						packet_to_send->type=3;
						packet_to_send->sender=TOS_NODE_ID;
						packet_to_send->destination=message->sender;
						packet_to_send->acked=1;
			

	                    if (call AMSend.send(message->sender, &globalPacket, sizeof(radio_msg_t)) == SUCCESS) {
                            //dbg("radio_send", "Sending SUBACK packet....\n");	
		                    locked = TRUE;
	                    }				       
					}//received a pub-message
				}else if(message->type == 4)
				{
				    dbg("radio_rec", " I'm the Pan Cordinator and I receive a PubMessage from %d on topic %d and payload %d...\n",message->sender, message->topic,message->payload);
				    for(i=0;i<8;i++){
    	                 if(message->sender == table[i].nodeID && table[i].connect==1)
    			               isPresent = TRUE; 
    	            }	
                
				   if(!isPresent){
                        dbg("radio_rec", "Node %d , you are not connected...\n",message-> sender);
                   }else{
     	                addObjectToSendToNodeRed(message->topic,message->payload);
                       	for(i=0; i<8; i++)
	                    {              	
	                	     if(table[i].topic == message->topic && table[i].topic != 10 && table[i].nodeID != message->sender)
	                	     {                                
                                  addObjectToSendToNode(table[i].nodeID,message->topic,message -> payload);
       	                    	    
	                	      }	      
	                    }                           
                    }
                  /*  accessObjects();
                    accessObjectsNode();*/
				}				
	   	    }else{  //If I am not the PANC
	   	    	if (message->type == 1 && message->acked== 1){
	   	    		// send the SUB
	   	    		flagConnect= TRUE;
	   	    		sendSub();
	   	    		call Timer0.startPeriodic(timeToPub);
	   	    	}
	   	    	if(message->type== 3){
	   	    	    flagSub=TRUE;
	   	    	
	   	    	}
	   	    	if(message->type== 4){
	   	    	    dbg("radio_rec", "I'm node %d and I receive a message on  topic %d...\n",TOS_NODE_ID,message->topic);	
	   	    	
	   	    	}
	   	    	
		    }
	   	}
	return bufPtr;
 }
 
 event void Boot.booted() {
    call AMControl.start();
 }
 
 event void AMControl.startDone(error_t err) {
	uint16_t firstTimeToPub;
	
	if (err == SUCCESS){
	    flagSub = FALSE;
	    flagConnect = FALSE ;
		if(TOS_NODE_ID == 9){
		    initializeRoutingTable();
		    call Timer1.startPeriodic(100);
		    call Timer2.startPeriodic(5000);
		}
		if (TOS_NODE_ID != 9){
		    timeToPub= call Random.rand32()%15000;
		    randPubTopic = call Random.rand32()%3;
		    sendConnect();
            firstTimeToPub= 1000+ call Random.rand16()%3000;//random time chooses
            call Timer0.startOneShot(firstTimeToPub);
		    //dbg("radio_send","randPubTopic : %d \n",randPubTopic);
		}
	}else 
	{
		call AMControl.start();
	}
 }
 
 event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent ,Check if the packet is sent */ 
	if (&globalPacket == bufPtr){
		locked = FALSE;            
		dbg("radio_send", "Packet sent...\n");
	}else{
		dbg("radio_send", "ERR SEND\n");
	}	
	
 }

 event void AMControl.stopDone(error_t err) {
 
 } 

}



