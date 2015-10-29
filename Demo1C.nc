/*
 * Demo Paper Distributed MasRS in the WSN
 * Version: Demo1
 *
 * - T:0x1205 should connect to the Basestation B:0x7F38.
 * *** While debugging, T:0x1205 connects to T:0x789B. ***
 * 
 * New Features in the Demo1:
 *   version#: details
 *   1: support multiple setup packages to send either 
 *      temp or light sensor data from telosbs to the principles
 *   2: write the am_send and busy to protect the racing condition 
 * 	to send the date while the transmitter is still busy
 *   3: change the message_t package -> message_t distributed_pck, 
 *      centralized_pck; 
 *   4: add the centralized timer to send the data directly to the 
 *      base station
 *   5: send the data directly to the base station when the 
 *      when the centralized algorithm fires.
 *      - the cen_timer = 0 skip, 1 send the data to the base station
 *      - cen_timer fires two times more often than dis_timer
 *   6: add package 10, 11, and 12  which have node_count
 *      - modified the receive function to correspond with 
 *      new packages 
 *   comment out the 6
 *   7: change the setup package and edit the code in the receive
 *      function to save the setup and forward it
 * Author: Panitan Wongse-ammat
 */

#include "Timer.h"
#include "Demo1.h"
#include <string.h>
#include <UserButton.h>
#define NEW_PRINTF_SEMANTICS
#include "printf.h"

module Demo1C @safe() {
  uses {
    interface Boot;

    interface Leds;

    interface Read<uint16_t> as LRead; // light sensor
    interface Read<uint16_t> as TRead; // temp sensor

    interface AMSend;
    interface Receive;
    interface Timer<TMilli> as Dis_Timer;
    interface Timer<TMilli> as Cen_Timer;

    interface AMPacket;
    interface Packet;
    interface SplitControl as AMControl;

    interface Get<button_state_t>;
    interface Notify<button_state_t>;
    
    interface CC2420Config;
    interface CC2420Power;
    interface Read<uint16_t> as ReadRssi;
    interface Resource;
  }
}

implementation // the implementation part
{				 
  message_t dis_packet;	// a packet for the distributed algorithm
  message_t cen_packet; // a packet for the centralized algorithm
  void* busy = NULL;
  // the connecting node between two telosb nodes 
  // having_buddy = TRUE
  // except the T:0x1205 -> FALSE 
  bool having_buddy = FALSE;
  bool connecting_node = FALSE;
  // node specific info
  uint16_t PRINCIPLE_ID = 0;
  uint16_t T_BUDDY_ID = 0;
  uint16_t T_BUDDY_ID2 = 0; // only for T:0x2728
  uint8_t  T_GROUP_ID = 0;
  uint16_t BASE_STATION_ID = 0x7F38;    //  uint16_t in AM.h
  // depends on how to send the pck1 to other nodes
  bool FW_PCK1_TO_BUDDY = TRUE;
  // if the light sensor value is read and sent,
  // lsensor_trigger = TRUE
  bool tsensor_trigger = FALSE;
  bool lsensor_trigger = FALSE;
  // keep the value of the reading sensor 
  uint16_t tsensor_reading = 0;
  uint16_t lsensor_reading = 0;
  // uint cen_timer 0 skip, 1 send 
  uint8_t cen_timer = 1;

  void setup() {
    // setup procedure
    T_GROUP_ID = (TOS_NODE_ID & 0xF000) >> 12;
    if(TOS_NODE_ID == 0x1205)
    { // it has to send the data to either the base station or 
      // its principle node
      PRINCIPLE_ID = 0X7F45;
      having_buddy = FALSE; 
      connecting_node = TRUE;
      FW_PCK1_TO_BUDDY = FALSE;
      // if the base station is changed, 
      /* BASE_STATION_ID = 0x7EB7;    //  uint16_t in AM.h */
    } else if(TOS_NODE_ID == 0x1003)
    {
      PRINCIPLE_ID = 0X7F45;
      T_BUDDY_ID = 0x0202;
      having_buddy = TRUE;
      connecting_node = TRUE;
    } else if(TOS_NODE_ID == 0x1715)
    {
      PRINCIPLE_ID = 0X7F45;
      T_BUDDY_ID = 0x3221;
      having_buddy = TRUE;
      connecting_node = TRUE;
    } else if(TOS_NODE_ID == 0x3221)
    {
      PRINCIPLE_ID = 0X7997;
      T_BUDDY_ID = 0x1715;
      having_buddy = TRUE;
      connecting_node = TRUE;
      FW_PCK1_TO_BUDDY = FALSE;
    } else if(TOS_NODE_ID == 0x0202)
    {
      PRINCIPLE_ID = 0X7EBA;
      T_BUDDY_ID = 0x1003;
      having_buddy = TRUE;
      connecting_node = TRUE;
      FW_PCK1_TO_BUDDY = FALSE;
    } else if(TOS_NODE_ID == 0x0712)
    {
      PRINCIPLE_ID = 0X7EBA;
      T_BUDDY_ID = 0x2218;
      having_buddy = TRUE;
      connecting_node = TRUE;
    } else if(TOS_NODE_ID == 0x2218)
    {
      PRINCIPLE_ID = 0X79A3;
      T_BUDDY_ID = 0x0712;
      having_buddy = TRUE;
      connecting_node = TRUE;
      FW_PCK1_TO_BUDDY = FALSE;
    } else if(TOS_NODE_ID == 0x2728)
    {
      PRINCIPLE_ID = 0X79A3;
      T_BUDDY_ID = 0x3529;
      having_buddy = TRUE;
      connecting_node = FALSE;
      FW_PCK1_TO_BUDDY = FALSE;
    
    } else if(TOS_NODE_ID == 0x3529)
    {
      PRINCIPLE_ID = 0X7997;
      T_BUDDY_ID = 0x2728;
      having_buddy = TRUE;
      connecting_node = FALSE;
      FW_PCK1_TO_BUDDY = FALSE;
    } else 

    { // other telosb nodes
      if(T_GROUP_ID == 0)
	PRINCIPLE_ID = 0x7EBA;
      else if(T_GROUP_ID == 1)
	PRINCIPLE_ID = 0x7F45;
      else if(T_GROUP_ID == 2)
	PRINCIPLE_ID = 0x79A3;
      else if(T_GROUP_ID == 3)
	PRINCIPLE_ID = 0x7997;
    }
    // the end of the setup procedure
  }
  void reset_setup_values() {
    // setting the timer
    if(call Dis_Timer.isRunning())
      call Dis_Timer.stop();

    if(call Cen_Timer.isRunning())
      call Cen_Timer.stop();
    // reset the sensor configuration
    lsensor_trigger = FALSE;
    tsensor_trigger = FALSE;
    tsensor_reading = 0;
    lsensor_reading = 0;
    cen_timer = 1;
    call Leds.led1Off();
    call Leds.led2Off();
  }
  void am_send(am_addr_t dst_addr, void* pck_ptr, uint sz) {
    // send the package
    // @dst_addr: am_addr_t the destination address
    // @pck_ptr: void* the pointer to the package
    // @sz: uint the size of the package
    if(!busy)
    {
      error_t err = call AMSend.send(dst_addr, pck_ptr, sz);
      if(err == SUCCESS) {
	busy = pck_ptr;
      } else {
	printf("am_send fail err: %d\n", err);
      }
    }
  }
  void fw_data(am_addr_t src_addr, void* pck_ptr, uint8_t sz) {
    // forward the data  either to principle or to buddy
    // @src_addr: am_addr_t the address of the source
    // @pck_ptr: void* the pointer to the package
    // @sz: uint the size of the package
    if(src_addr == PRINCIPLE_ID)
    {
      am_send(T_BUDDY_ID, pck_ptr, sz);
      printf("fw data to 0x%04X\n", T_BUDDY_ID);
    } else if(src_addr == T_BUDDY_ID)
    {
      am_send(PRINCIPLE_ID, pck_ptr, sz);
      printf("fw data to 0x%04X\n", PRINCIPLE_ID);
    }
  }
  void read_sensors() {
    // read sensors based on the setup package
    if(tsensor_trigger)
      call TRead.read();

    if(lsensor_trigger)
      call LRead.read();
  }

  event void Boot.booted() // when booted these functions will be called
  { 
    // setup procedure
    setup();

    call Leds.led0On();
    printf("\n\n\n\n-- Date: %s Time: %s --\n", __DATE__, __TIME__);
    printf("*** Node ID: 0x%04X Group: %d, Principle_id: 0x%X T_BUDDY_ID: 0x%X ***\n",
	   TOS_NODE_ID, T_GROUP_ID, PRINCIPLE_ID, T_BUDDY_ID);
    printf("*** Basestation ID: B:0x%04X B:%d***\n\n", 
	   BASE_STATION_ID, BASE_STATION_ID);
    /* printf("*** TOSH_DATA_LENGTH: %d ***\n", TOSH_DATA_LENGTH); */
    call CC2420Config.setPanAddr(1);
    call CC2420Config.setChannel(26);
    call AMControl.start();
    call Notify.enable();  

    printfflush();  
  }

  event void TRead.readDone(error_t result, uint16_t data) 
  { // when the Temperature sensor is done, process the data
    // call TRead.read();
    if (result == SUCCESS)
    {
      int16_t temp = -38.4 + 0.0098 * data; // temp = 30c or 85f when data = 7000
      printf("TSensor reading data: %u temp: %d\n", data, temp);
      tsensor_reading = data;

    } else
      printf("TSensor fails\n");
  }  

  event void LRead.readDone(error_t result, uint16_t data) 
  { // when the Light sensor is done, process the data
    if (result == SUCCESS)
    {
      printf("LSensor reading data: %u\n", data);
      lsensor_reading = data;

    } else
      printf("LSensor fails\n");
  }  

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if((error == SUCCESS) && (bufPtr == busy))
      busy = NULL;
    else 
      printf("send fail S: %d, Err: %d, busy: %p, b*: %p\n",
	     SUCCESS, error, busy, bufPtr);
  }

  event void AMControl.startDone(error_t err) 
  {
    if (err != SUCCESS) {
      call AMControl.start();
    }
    printf("*** Radio initialized ***\n");
  }

  event void Cen_Timer.fired() {
    // if fired, send teh data to the base station
    if(cen_timer == 0)
    { // skip
      cen_timer = 1;
      return;
    } else if(cen_timer == 1)
    {
      printf("\n\nCen Timer fire\n");
      read_sensors();
      if((tsensor_trigger == FALSE) && (lsensor_trigger == TRUE))
      { // light sensor 
	radio_msg_8* pck8 = (radio_msg_8*) call Packet.getPayload(&cen_packet, sizeof(radio_msg_8));
	printf("Msg8 send to 0x%04X\n", BASE_STATION_ID);
	pck8->pck_type = 8;
	pck8->lsensor_reading = lsensor_reading;
	am_send(BASE_STATION_ID, &cen_packet, sizeof(radio_msg_8));

      } else if((tsensor_trigger == TRUE) && (lsensor_trigger == FALSE))
      { // temp sensor 
	radio_msg_9* pck9 = (radio_msg_9*) call Packet.getPayload(&cen_packet, sizeof(radio_msg_9));
	printf("Msg9 send to 0x%04X\n", BASE_STATION_ID);
	pck9->pck_type = 9;
	pck9->tsensor_reading = tsensor_reading;
	am_send(BASE_STATION_ID, &cen_packet, sizeof(radio_msg_9));
      } 
      cen_timer = 0; // last line 
    }
  }

  event void Dis_Timer.fired() {
    // if fired, send the data to the principle node
    printf("\n^^^ Dis Timer fired ^^^\n");
    if((tsensor_trigger == FALSE) && (lsensor_trigger == TRUE))
    {
      radio_msg_2* pck2 = (radio_msg_2*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_2));
      printf("Msg2 send to 0x%04X\n", PRINCIPLE_ID);
      pck2->type = 2;
      pck2->lsensor_reading = lsensor_reading;
      am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_2));

    } else if((tsensor_trigger == TRUE) && (lsensor_trigger == FALSE))
    {
      radio_msg_3* pck3 = (radio_msg_3*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_3));
      printf("Msg3 send to 0x%04X\n", PRINCIPLE_ID);
      pck3->type = 3;
      pck3->tsensor_reading = tsensor_reading;
      am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_3));

    }/*  else if((tsensor_trigger == TRUE) && (lsensor_trigger == TRUE)) */
    /* { */
    /*   radio_msg_4* pck4 = (radio_msg_4*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_4)); */
    /*   printf("Msg4 send to 0x%04X\n", PRINCIPLE_ID); */
    /*   pck4->type = 4; */
    /*   pck4->lsensor_reading = lsensor_reading; */
    /*   pck4->tsensor_reading = tsensor_reading; */
    /*   am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_4)); */
    /* } */
    printf("^^^ Dis Timer fired end ^^^\n");
    printfflush();
  } // event void Dis_Timer.fired() 

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, 
				   uint8_t len) 
  { 
    am_addr_t src_addr = call AMPacket.source(bufPtr);
    am_addr_t dst_addr = 0;
    uint8_t pck_type = ((radio_msg_0*) payload)->type;
    printf("\n\n\nRx\n");
    if(!((src_addr == T_BUDDY_ID) ||
	 (src_addr == PRINCIPLE_ID) || 
	 (src_addr == BASE_STATION_ID) ||
	 (pck_type == 0)))
    { // if the package is not detined to be received by this node,
      // return immediately.
      printfflush();
      return bufPtr;
    }
    dst_addr = call AMPacket.destination(bufPtr);
    printf("Data type: %u, len: %u\n", pck_type, len);
    printf("Dst Addr: 0x%04X | Src Addr: 0x%04X\n", dst_addr, src_addr);

    if(pck_type == 0)
    { // reset
      radio_msg_0 msg0 = *((radio_msg_0*) payload);
      printfflush();
      call Leds.led0Off();
      if(msg0.flooding == FLOODING_CONSTANT)
      {
	WDTCTL = WDT_ARST_1_9;
	while(1);
      }
    } else if(pck_type == 15)
    { // setup
      radio_msg_t* msg = (radio_msg_t*) payload;
      uint16_t delay_sec = msg->data[1];
      uint16_t sensor_type = msg->data[2];
      if(src_addr == PRINCIPLE_ID)
      { 
	// the principle mode will broadcast the pck1
	// telosb nodes should check the src_addr == 
	// their principle node
	// select the message type
	printf("Msg1 %d [(delay: %d), (sensor_type: %d)]\n", 
	       pck_type, delay_sec, sensor_type);
	printf("Save the setup\n");
	reset_setup_values();
	// set up the sensor config
	if(sensor_type == 2)
	{
	  lsensor_trigger = TRUE;
	  call Leds.led1On();
	} else if(sensor_type == 3)
	{
	  tsensor_trigger = TRUE;
	  call Leds.led2On();
	}
	// BASE_STATION_ID = msg->data[0];

	if(having_buddy && FW_PCK1_TO_BUDDY)
	{ // forward to the buddy telosb
	  radio_msg_t* pck1_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_1));
	  printf("fw to 0x%04X\n", T_BUDDY_ID);
	  // void *memcpy(void *dest, const void *src, size_t n)
	  memcpy(pck1_fw, msg, sizeof(radio_msg_t));
	  am_send(T_BUDDY_ID, &dis_packet, sizeof(radio_msg_t));
	}

	// timer in the millisecond unit
	call Dis_Timer.startPeriodic(delay_sec * 1000);
	call Cen_Timer.startPeriodic(delay_sec * 500);

      } else if((src_addr == T_BUDDY_ID) ||
		((src_addr == BASE_STATION_ID) && (TOS_NODE_ID == 0x1205)))
      {
	// the connecting node forwards the data to its buddy
	// it is T:0x1205 and receive the pck from base station
	radio_msg_t* pck1_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_t));
	printf("fw to HC: %d S:0x%X\n", T_GROUP_ID, PRINCIPLE_ID);
	// void *memcpy(void *dest, const void *src, size_t n)
	memcpy(pck1_fw, msg, sizeof(radio_msg_t));
	am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_t));
      }
      // end pck_type == 1
    } else if((pck_type == 5) && 
	      ((src_addr == T_BUDDY_ID) || 
	       ((src_addr == PRINCIPLE_ID) && (connecting_node == TRUE))))
    { // forward the package to its buddy or its principle
      uint8_t i = 0;
      radio_msg_5* msg5 = (radio_msg_5*) payload;
      radio_msg_5* pck5_fw = (radio_msg_5*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_5));
      // void *memcpy(void *dest, const void *src, size_t n)
      memcpy(pck5_fw, msg5, sizeof(radio_msg_5));
      fw_data(src_addr, &dis_packet, sizeof(radio_msg_5));
      /* if(src_addr == PRINCIPLE_ID) */
      /* { */
      /* 	am_send(T_BUDDY_ID, &dis_packet, sizeof(radio_msg_5)); */
      /* 	printf("fw data to 0x%04X\n", T_BUDDY_ID); */
      /* } else if(src_addr == T_BUDDY_ID) */
      /* { */
      /* 	am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_5)); */
      /* 	printf("fw data to 0x%04X\n", PRINCIPLE_ID); */
      /* } */
    /* } else if((pck_type == 10) &&  */
    /* 	      ((src_addr == T_BUDDY_ID) ||  */
    /* 	       ((src_addr == PRINCIPLE_ID) && (connecting_node == TRUE)))) */
    /* { // forward the package to its buddy or its principle */
    /*   uint8_t i = 0; */
    /*   radio_msg_10* msg10 = (radio_msg_10*) payload; */
    /*   radio_msg_10* pck10_fw = (radio_msg_10*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_10)); */
    /*   // void *memcpy(void *dest, const void *src, size_t n) */
    /*   memcpy(pck10_fw, msg10, sizeof(radio_msg_10)); */

    /*   if(src_addr == PRINCIPLE_ID) */
    /*   { */
    /* 	am_send(T_BUDDY_ID, &dis_packet, sizeof(radio_msg_10)); */
    /* 	printf("fw data to 0x%04X\n", T_BUDDY_ID); */
    /*   } else if(src_addr == T_BUDDY_ID) */
    /*   { */
    /* 	am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_10)); */
    /* 	printf("fw data to 0x%04X\n", PRINCIPLE_ID); */
    /*   } */
    } else if((pck_type == 6) && 
	      ((src_addr == T_BUDDY_ID) || 
	       ((src_addr == PRINCIPLE_ID) && (connecting_node == TRUE))))
    { // forward the package to its buddy or its principle
      radio_msg_6* msg6 = (radio_msg_6*) payload;
      radio_msg_6* pck6_fw = (radio_msg_6*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_6));
      memcpy(pck6_fw, msg6, sizeof(radio_msg_6));
      fw_data(src_addr, &dis_packet, sizeof(radio_msg_6));
      /* if(src_addr == PRINCIPLE_ID) */
      /* { */
      /* 	am_send(T_BUDDY_ID, &dis_packet, sizeof(radio_msg_6)); */
      /* 	printf("fw data to 0x%04X\n", T_BUDDY_ID); */
      /* } else if(src_addr == T_BUDDY_ID) */
      /* { */
      /* 	am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_6)); */
      /* 	printf("fw data to 0x%04X\n", PRINCIPLE_ID); */
      /* } */
    /* } else if((pck_type == 11) &&  */
    /* 	      ((src_addr == T_BUDDY_ID) ||  */
    /* 	       ((src_addr == PRINCIPLE_ID) && (connecting_node == TRUE)))) */
    /* { // forward the package to its buddy or its principle */
    /*   radio_msg_11* msg11 = (radio_msg_11*) payload; */
    /*   radio_msg_11* pck11_fw = (radio_msg_11*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_11)); */
    /*   memcpy(pck11_fw, msg11, sizeof(radio_msg_11)); */

    /*   if(src_addr == PRINCIPLE_ID) */
    /*   { */
    /* 	am_send(T_BUDDY_ID, &dis_packet, sizeof(radio_msg_11)); */
    /* 	printf("fw data to 0x%04X\n", T_BUDDY_ID); */
    /*   } else if(src_addr == T_BUDDY_ID) */
    /*   { */
    /* 	am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_11)); */
    /* 	printf("fw data to 0x%04X\n", PRINCIPLE_ID); */
    /*   } */
	       
    } else if((pck_type == 7) && (TOS_NODE_ID == 0x1205))
    { // only T:0x1205 will handle this case
      radio_msg_7* msg7 = (radio_msg_7*) payload;
      radio_msg_7* pck7_fw = (radio_msg_7*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_7));
      memcpy(pck7_fw, msg7, sizeof(radio_msg_7));
      am_send(BASE_STATION_ID, &dis_packet, sizeof(radio_msg_7));
      printf("fw data to 0x%04X\n", BASE_STATION_ID);
    } /* else if((pck_type == 12) && (TOS_NODE_ID == 0x1205)) */
    /* { // only T:0x1205 will handle this case */
    /*   radio_msg_12* msg12 = (radio_msg_12*) payload; */
    /*   radio_msg_12* pck12_fw = (radio_msg_12*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_12)); */
    /*   memcpy(pck7_fw, msg12, sizeof(radio_msg_12)); */
    /*   am_send(BASE_STATION_ID, &dis_packet, sizeof(radio_msg_12)); */
    /*   printf("fw data to 0x%04X\n", BASE_STATION_ID); */
    /* } */
    else if((pck_type == 13) && 
	    ((TOS_NODE_ID == 0x2728) || (TOS_NODE_ID == 0x3529)))
    {
      radio_msg_13* msg13 = (radio_msg_13*) payload;
      radio_msg_13* pck13_fw = (radio_msg_13*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_13));
      memcpy(pck13_fw, msg13, sizeof(radio_msg_13));
      fw_data(src_addr, &dis_packet, sizeof(radio_msg_13));
    }

    printfflush();
    return bufPtr;
  }

  event void Notify.notify(button_state_t val) {}
  event void AMControl.stopDone(error_t err) {}
  event void CC2420Config.syncDone(error_t err) {}
  async event void CC2420Power.startOscillatorDone() {}
  async event void CC2420Power.startVRegDone() {}
  event void ReadRssi.readDone(error_t result, uint16_t val) {}
  event void Resource.granted() {}
}

