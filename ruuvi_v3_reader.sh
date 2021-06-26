#!/bin/bash

RUUVI_BT_MAC=
RUUVI_READ_TIMEOUT_S=10

get_acceleration_value()
{
  ACCL_RAW=$(($1 << 8 | $2))

  SIGN=
  if [ $((${ACCL_RAW} & 0x8000)) -ne 0 ]; then
    ACCL_RAW=$((0x7FFF & ~(ACCL_RAW - 1)))
    SIGN=-
  fi

  printf -v ACCL_RAW_PREPEND "%.6d\n" $ACCL_RAW
  if [ $ACCL_RAW -gt 9999 ]; then
    ACCL_MAJOR=$(echo $ACCL_RAW_PREPEND | cut -c 2-3)
  else
    ACCL_MAJOR=$(echo $ACCL_RAW_PREPEND | cut -c 3-3)
  fi

  ACCL_MINOR=$(echo $ACCL_RAW_PREPEND | cut -c 4-6)

  echo ${SIGN}${ACCL_MAJOR}.${ACCL_MINOR}
}

while [ -n "$1" ]; do
  case $1 in
  --mac)
    shift
    RUUVI_BT_MAC=$1
  ;;
  --timeout)
    shift
    RUUVI_READ_TIMEOUT_S=$1
    test $RUUVI_READ_TIMEOUT_S -gt 0 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Timeout needs to be greater than zero"
      exit 1
    fi
  ;;
  *)
    echo "Unknown command $1"
    exit 1
  ;;
  esac
  shift
done

if [ -z $RUUVI_BT_MAC ]; then
  echo "Ruuvi tag MAC in format AA:BB:CC:DD:EE:FF needed (--mac <MAC>)"
  exit 1
fi

BEACON_DATA=$(bluetoothctl --timeout ${RUUVI_READ_TIMEOUT_S} scan on)
if [ $? -ne 0 ]; then
  echo "bluetoothctl failed to read"
  exit 1
fi

RUUVI_BEACON=$(echo "${BEACON_DATA}" | grep -A1 "${RUUVI_BT_MAC} ManufacturerData Value" | tail -n 1)
RUUVI_BEACON=$(echo ${RUUVI_BEACON} | awk '{ print toupper($0) }')
if [ "$RUUVI_BEACON " = " " ]; then
  echo "Failed to read ruuvi beacon"
  exit 1
fi

RUUVI_FORMAT=$(echo $RUUVI_BEACON | awk {'print $1}')
if [ "$RUUVI_FORMAT " != "03 " ]; then
  echo "This script supports only ruuvi v3 tags. Format was ${RUUVI_FORMAT}."
  exit 1
fi

HUMI_RAW=$(echo $RUUVI_BEACON | awk {'print $2}')
BC_HUMI_STR="ibase=16;scale=1;${HUMI_RAW}/2"
HUMIDITY_RH=$(echo $BC_HUMI_STR | bc)

TEMP_MAJOR=0x$(echo $RUUVI_BEACON | awk {'print $3}')
TEMP_MINOR=0x$(echo $RUUVI_BEACON | awk {'print $4}')
if [ $((${TEMP_MAJOR} & 0x80)) -ne 0 ]; then
  TEMP_MAJOR=-$((0x7F & TEMP_MAJOR))
fi

printf -v TEMPERATURE_C "%d.%02d" ${TEMP_MAJOR} ${TEMP_MINOR}

PRESS_MAJOR=0x$(echo $RUUVI_BEACON | awk {'print $5}')
PRESS_MINOR=0x$(echo $RUUVI_BEACON | awk {'print $6}')
PRESSURE_RAW=$((PRESS_MINOR | PRESS_MAJOR << 8))
PRESSURE_RAW=$((PRESSURE_RAW + 50000))
BC_PRESSURE_STR="ibase=10;scale=2;${PRESSURE_RAW}/100"
PRESSURE_HPA=$(echo $BC_PRESSURE_STR | bc)

ACCL_X_RAW_MAJOR=0x$(echo $RUUVI_BEACON | awk {'print $7}')
ACCL_X_RAW_MINOR=0x$(echo $RUUVI_BEACON | awk {'print $8}')
ACC_X=$(get_acceleration_value $ACCL_X_RAW_MAJOR $ACCL_X_RAW_MINOR)

ACCL_Y_RAW_MAJOR=0x$(echo $RUUVI_BEACON | awk {'print $9}')
ACCL_Y_RAW_MINOR=0x$(echo $RUUVI_BEACON | awk {'print $10}')
ACC_Y=$(get_acceleration_value $ACCL_Y_RAW_MAJOR $ACCL_Y_RAW_MINOR)

ACCL_Z_RAW_MAJOR=0x$(echo $RUUVI_BEACON | awk {'print $11}')
ACCL_Z_RAW_MINOR=0x$(echo $RUUVI_BEACON | awk {'print $12}')
ACC_Z=$(get_acceleration_value $ACCL_Z_RAW_MAJOR $ACCL_Z_RAW_MINOR)

BATTERY_MAJOR=0x$(echo $RUUVI_BEACON | awk {'print $13}')
BATTERY_MINOR=0x$(echo $RUUVI_BEACON | awk {'print $14}')
BATTERY_RAW=$((BATTERY_MAJOR << 8 | BATTERY_MINOR))
BC_VOLTAGE_STR="ibase=10;scale=3;${BATTERY_RAW}/1000"
BATTERY_VOLTAGE=$(echo $BC_VOLTAGE_STR | bc)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

OBSERVATION="{\"observation_time\":\"${TIMESTAMP}\", \"temperature\":${TEMPERATURE_C},\
              \"pressure\":${PRESSURE_HPA}, \"humidity\":${HUMIDITY_RH},\
              \"accl_x\":${ACC_X}, \"accl_y\":${ACC_Y}, \"accl_z\":${ACC_Z},\
              \"battery_voltage\":${BATTERY_VOLTAGE}}"

echo $OBSERVATION

exit 0
