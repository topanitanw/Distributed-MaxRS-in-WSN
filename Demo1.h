#ifndef DEMO0_H
#define DEMO0_H

typedef nx_struct radio_type_0_msg 
{
  nx_uint8_t type;
  nx_uint8_t flooding;
} radio_msg_0;

typedef nx_struct radio_type_1_msg 
{
  nx_uint8_t type;
  nx_uint8_t delay_s;
  nx_uint8_t sensor_type;
} radio_msg_1;

typedef nx_struct radio_type_2_msg 
{
  nx_uint8_t type;
  nx_uint16_t lsensor_reading;
} radio_msg_2;

typedef nx_struct radio_type_3_msg 
{
  nx_uint8_t type;
  nx_uint16_t tsensor_reading;
} radio_msg_3;

typedef nx_struct radio_type_4_msg 
{
  nx_uint8_t type;
  nx_uint16_t lsensor_reading;
  nx_uint16_t tsensor_reading;
} radio_msg_4;

typedef nx_struct radio_type_5_msg 
{
  nx_uint8_t type;
  nx_uint16_t sensors_8[8];
} radio_msg_5;

typedef nx_struct radio_type_6_msg 
{
  nx_uint8_t type;
  nx_uint16_t sensors_16[16];
} radio_msg_6;

typedef nx_struct radio_type_7_msg 
{
  nx_uint8_t type;
  nx_uint16_t sensors_32[32];
} radio_msg_7;

typedef nx_struct radio_type_8_msg 
{
  nx_uint8_t pck_type;
  nx_uint16_t lsensor_reading;
} radio_msg_8;

typedef nx_struct radio_type_9_msg 
{
  nx_uint8_t pck_type;
  nx_uint16_t tsensor_reading;
} radio_msg_9;

/* typedef nx_struct radio_type_10_msg  */
/* { */
/*   nx_uint8_t type; */
/*   nx_uint8_t node_count; */
/*   nx_uint16_t sensors_8[8]; */
/* } radio_msg_10; */

/* typedef nx_struct radio_type_11_msg  */
/* { */
/*   nx_uint8_t type; */
/*   nx_uint8_t node_count; */
/*   nx_uint16_t sensors_16[16]; */
/* } radio_msg_11; */

/* typedef nx_struct radio_type_12_msg  */
/* { */
/*   nx_uint8_t type; */
/*   nx_uint8_t node_count; */
/*   nx_uint16_t sensors_32[32]; */
/* } radio_msg_12; */

// define constants based on telosb node id
enum {
/* #if TOS_NODE_ID == 0x1205 */
/*   PRINCIPLE_ID = 0X7997, */
/*   T_NEXT_ID = 0, */

/* #elif TOS_NODE_ID == 0x1003 */
/*   PRINCIPLE_ID = 0X7F45, */
/*   T_NEXT_ID = 0x0202, */

/* #elif TOS_NODE_ID == 0x1715 */
/*   PRINCIPLE_ID = 0X7F45, */
/*   T_NEXT_ID = 0x3221, */

/* #elif TOS_NODE_ID == 0x3221 */
/*   PRINCIPLE_ID = 0X7997, */
/*   T_NEXT_ID = 0x1715, */

/* #elif TOS_NODE_ID == 0x0202 */
/*   PRINCIPLE_ID = 0X7EBA, */
/*   T_NEXT_ID = 0x1003, */

/* #elif TOS_NODE_ID == 0x0712 */
/*   PRINCIPLE_ID = 0X7EBA, */
/*   T_NEXT_ID = 0x2218, */

/* #elif TOS_NODE_ID == 0x2218 */
/*   PRINCIPLE_ID = 0X79A3, */
/*   T_NEXT_ID = 0x0712, */

/* #endif /\* #if *\/ */

  AM_RADIO_SENSE_MSG = 0x25,   //  unit8_t in AM.h : 37 = 0x25
  // AM_BROADCAST_ADDR = 0xFFFF already defined in AM.h
  BASE_STATION_ID = 0x789B,    //  uint16_t in AM.h
  FLOODING_CONSTANT = 0xFF,    //  flooding constant 8 bits
  LSENSOR_TH = 100, 
  TSENSOR_TH = 25
};
#endif /* DEMO0_H */
