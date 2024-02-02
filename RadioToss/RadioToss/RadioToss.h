#ifndef RADIO_TOSS_H
#define RADIO_TOSS_H

typedef nx_struct radio_msg_table {
	nx_int16_t type;//0 ->con; 1-> conAck, 2-> sub, 3-> subBack, 4-> pub
	nx_int16_t sender; // id of the sender
	nx_int16_t destination;//id of the pan
	nx_int16_t topic; // 0 ->Temperature; 1 -> Humidity ; 2 -> Luminosity
	nx_int16_t payload;// number that contain a value
	nx_int16_t acked;
		                    	
} radio_msg_t;



enum {
  AM_RADIO_COUNT_MSG = 10,
};


#endif
