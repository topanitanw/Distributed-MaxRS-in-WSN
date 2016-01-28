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
 *      ### have the radio_msg_t
 *   8: edit the receiver function for all clusters
 *      to handle all pck_type
 * Author: Panitan Wongse-ammat
 */

#include "Timer.h"
#include "Demo1.h"
#include <string.h> // memcpy
#include <UserButton.h>
#define NEW_PRINTF_SEMANTICS // printf
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
  /* const uint16_t T_TO_BASEST = 0x1205;  */
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
  uint16_t BASE_STATION_ID = 0;    //  uint16_t in AM.h
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
      BASE_STATION_ID = 0x7F38;    //  uint16_t in AM.h
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
      printf("fw data to BUDDY: 0x%04X\n", T_BUDDY_ID);
    } else if(src_addr == T_BUDDY_ID)
    {
      am_send(PRINCIPLE_ID, pck_ptr, sz);
      printf("fw data to PN: 0x%04X\n", PRINCIPLE_ID);
    }
  }
  void read_sensors() {
    // read sensors based on the setup package
    if(tsensor_trigger)
      call TRead.read();

    if(lsensor_trigger)
      call LRead.read();
  }
  event void Boot.booted() {
    // when booted these functions will be called
    // setup procedure
    setup();

    call Leds.led0On();
    printf("\n\n\n\n-- Date: %s Time: %s --\n", __DATE__, __TIME__);
    printf("*** Node ID: 0x%04X Group: %d, Principle_id: 0x%04X T_BUDDY_ID: 0x%04X ***\n",
	   TOS_NODE_ID, T_GROUP_ID, PRINCIPLE_ID, T_BUDDY_ID);
    printf("*** Basestation ID: B:0x%04X ***\n\n", BASE_STATION_ID);
    /* printf("*** TOSH_DATA_LENGTH: %d ***\n", TOSH_DATA_LENGTH); */
    call CC2420Config.setPanAddr(1);
    call CC2420Config.setChannel(26);
    call AMControl.start();
    call Notify.enable();  

    printfflush();  
  }

  event void TRead.readDone(error_t result, uint16_t data) {
    // when the Temperature sensor is done, process the data
    if (result == SUCCESS)
    {
      int16_t temp = -38.4 + 0.0098 * data; // temp = 30c or 85f when data = 7000
      printf("TSensor reading data: %u temp: %d\n", data, temp);
      tsensor_reading = data;

    } else
      printf("TSensor fails\n");
  }  

  event void LRead.readDone(error_t result, uint16_t data) {
    // when the Light sensor is done, process the data
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

  event void AMControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call AMControl.start();
    }
    printf("*** Radio initialized ***\n");
  }

  event void Cen_Timer.fired() {
    // if fired, send teh data to the base station
    radio_msg_89* pck_89 = NULL;
    if(cen_timer == 0)
    { // skip
      cen_timer = 1;
      return;
    } else if(cen_timer == 1)
    {
      pck_89 = (radio_msg_89*) call Packet.getPayload(&cen_packet, sizeof(radio_msg_89));
      read_sensors();
      printf("\n\nCen Timer fire\n");
      if((tsensor_trigger == FALSE) && (lsensor_trigger == TRUE))
      { // light sensor 
	printf("Msg8 send to BS: 0x%04X\n", BASE_STATION_ID);
	pck_89->pck_type = 8;
	pck_89->sensor_reading = lsensor_reading;
      } else if((tsensor_trigger == TRUE) && (lsensor_trigger == FALSE))
      { // temp sensor 
	printf("Msg9 send to BS: 0x%04X\n", BASE_STATION_ID);
	pck_89->pck_type = 9;
	pck_89->sensor_reading = tsensor_reading;
      } 
      am_send(BASE_STATION_ID, &cen_packet, sizeof(radio_msg_89));
      cen_timer = 0; 
    } // end else if(cen_timer == 1)
  }

  event void Dis_Timer.fired() {
    // if fired, send the data to the principle node
    printf("\n^^^ Dis Timer fired ^^^\n");
    if((tsensor_trigger == FALSE) && (lsensor_trigger == TRUE))
    {
      radio_msg_2* pck2 = (radio_msg_2*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_2));
      printf("Msg2 send to PN: 0x%04X\n", PRINCIPLE_ID);
      pck2->type = 2;
      pck2->lsensor_reading = lsensor_reading;
      am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_2));

    } else if((tsensor_trigger == TRUE) && (lsensor_trigger == FALSE))
    {
      radio_msg_3* pck3 = (radio_msg_3*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_3));
      printf("Msg3 send to PN: 0x%04X\n", PRINCIPLE_ID);
      pck3->type = 3;
      pck3->tsensor_reading = tsensor_reading;
      am_send(PRINCIPLE_ID, &dis_packet, sizeof(radio_msg_3));
    }
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
    { // if the package is not destined to be received by this node,
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
      printf("test %d\n", msg0.flooding);
      printfflush();
      call Leds.led0Off();
      if(msg0.flooding == FLOODING_CONSTANT)
      { // reset the node
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
	BASE_STATION_ID = msg->data[0]; // 0 -> base station id
	printf("Base station ID: 0x%0X\n", BASE_STATION_ID);
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
	
	if(having_buddy && FW_PCK1_TO_BUDDY)
	{ // forward to the buddy telosb
	  radio_msg_t* pck1_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_t));
	  printf("fw to BUDDY: 0x%04X\n", T_BUDDY_ID);
	  // void *memcpy(void *dest, const void *src, size_t n)
	  memcpy(pck1_fw, msg, sizeof(radio_msg_t));
	  am_send(T_BUDDY_ID, &dis_packet, sizeof(radio_msg_t));
	}

	// timer in the millisecond unit
	call Dis_Timer.startPeriodic(delay_sec * 1000);
	/* call Cen_Timer.startPeriodic(delay_sec * 500); */
	call Cen_Timer.startPeriodic(1789); // 1.789 sec

      } else if((src_addr == T_BUDDY_ID) ||
		((src_addr == BASE_STATION_ID) && 
		 (TOS_NODE_ID == 0x1205)))
      {
	// the connecting node forwards the data to its principle node
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
	       ((src_addr == PRINCIPLE_ID) && 
		(connecting_node == TRUE))))
    { // forward the package to its buddy or its principle
      uint8_t i = 0;
      radio_msg_t* msg_t = (radio_msg_t*) payload;
      radio_msg_t* pck_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_t));
      // void *memcpy(void *dest, const void *src, size_t n)
      memcpy(pck_fw, msg_t, sizeof(radio_msg_t));
      fw_data(src_addr, &dis_packet, sizeof(radio_msg_t));

    } else if((pck_type == 6) && 
	      ((src_addr == T_BUDDY_ID) || 
	       ((src_addr == PRINCIPLE_ID) && 
		(connecting_node == TRUE))))
    { // forward the package to its buddy or its principle
      radio_msg_t* msg_t = (radio_msg_t*) payload;
      radio_msg_t* pck_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_t));
      memcpy(pck_fw, msg_t, sizeof(radio_msg_t));
      fw_data(src_addr, &dis_packet, sizeof(radio_msg_t));

    } else if((pck_type == 7) && (TOS_NODE_ID == 0x1205))
    { // only T:0x1205 will handle this case
      radio_msg_t* msg_t = (radio_msg_t*) payload;
      radio_msg_t* pck_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_t));
      memcpy(pck_fw, msg_t, sizeof(radio_msg_t));
      am_send(BASE_STATION_ID, &dis_packet, sizeof(radio_msg_t));
      printf("send data to BS: 0x%04X\n", BASE_STATION_ID);

    } else if((pck_type == 13) && 
	      ((TOS_NODE_ID == 0x2728) || (TOS_NODE_ID == 0x3529)))
    { // send the data across cluster 2 to cluster 3
      radio_msg_t* msg_t = (radio_msg_t*) payload;
      radio_msg_t* pck_fw = (radio_msg_t*) call Packet.getPayload(&dis_packet, sizeof(radio_msg_t));
      memcpy(pck_fw, msg_t, sizeof(radio_msg_t));
      fw_data(src_addr, &dis_packet, sizeof(radio_msg_t));
      printf("fw data to across 0x%04X\n", src_addr);
    }

    printfflush();
    return bufPtr;
  } // Receive.receive

  event void Notify.notify(button_state_t val) {
    // print out the info when the button is pressed
    if(val == BUTTON_PRESSED)
    {
      printf("\n\n\n\n-- Date: %s Time: %s --\n", __DATE__, __TIME__);
      printf("*** Node ID: 0x%04X Group: %d, Principle_id: 0x%04X T_BUDDY_ID: 0x%04X ***\n", 
	     TOS_NODE_ID, T_GROUP_ID, PRINCIPLE_ID, T_BUDDY_ID);
      printf("*** Basestation ID: B:0x%04X ***\n\n", BASE_STATION_ID);
      printfflush();    
    }
  }

  event void AMControl.stopDone(error_t err) {}
  event void CC2420Config.syncDone(error_t err) {}
  async event void CC2420Power.startOscillatorDone() {}
  async event void CC2420Power.startVRegDone() {}
  event void ReadRssi.readDone(error_t result, uint16_t val) {}
  event void Resource.granted() {}
}

