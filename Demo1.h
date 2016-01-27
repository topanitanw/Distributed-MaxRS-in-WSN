#ifndef DEMO1_H
#define DEMO1_H

enum {
  // unit8_t in AM.h : 37 = 0x25
  // 65 = 0x41, 
  AM_RADIO_SENSE_MSG = 0x41,   
  // AM_BROADCAST_ADDR = 0xFFFF already defined in AM.h
  FLOODING_CONSTANT = 0xFF,    //  flooding constant 8 bits
  MAX_DATA_SZ = 44
};

// package 0, 2, 3, 8, 9
typedef nx_struct radio_type_0_msg 
{
  nx_uint8_t type;
  nx_uint8_t flooding;
} radio_msg_0;

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

// for the package type 8 and 9
typedef nx_struct radio_type_89_msg 
{
  nx_uint8_t pck_type;
  nx_uint16_t sensor_reading;
} radio_msg_89;

typedef nx_struct 
{
  nx_uint8_t pck_type;
  nx_int16_t data[MAX_DATA_SZ];
} radio_msg_t;
// define constants based on telosb node id
#endif /* DEMO1_H */
