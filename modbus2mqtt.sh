#! /bin/sh

MODBUS_SERVER=127.0.0.1
MODBUS_PORT=502
MQTT_SERVER=127.0.0.1

# 
usage () {
  echo "USAGE: $@"
  exit 1
}

# bc is not installed
float_div () {
  x=$1
  y=$2
  q=$(( $x / $y ))
  r=$(( $x % $y ))
  echo "$q.$r" 
}

float_div_10 () {
  float_div "$@" 10
}

ip_conv () {
  echo $1 | sed -e 's/,/\./g'
}

read_modbus () {
  reg=$1
  size=$2
  type=$3
  conv=""
  if [ "${type}" = "ascii" ]; then
     conv="echo -e"
  elif [ "${type}" = "temp" ]; then
    type="32bit_int1234"
    conv="float_div_10"
  elif [ "${type}" = "ip" ]; then
    type="8bit_uint"
    conv="ip_conv"
  fi
  ret=$(modbus_tcp_test ${MODBUS_SERVER} ${MODBUS_PORT} 1 1 3 ${reg} ${size} ${type} 1)
  if [ -n "${conv}" ]; then
    ret=$(${conv} ${ret})
  fi
  echo ${ret}
}

add_payload () {
  payload=$1
  name=$2
  reg=$3
  size=$4
  type=$5
  value=$(read_modbus ${reg} ${size} ${type})
  comma=", "
  [ -z "${payload}" ] && comma=""
  payload="${payload}${comma}\"${name}\": ${value}"
  echo "${payload}"
}

mqtt_pub () {
  topic=$1
  payload=$2
  curl -d "{ ${payload} }" mqtt://${MQTT_SERVER}/${topic}
}

