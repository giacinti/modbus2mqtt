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
  echo "\"$(echo $1 | sed -e 's/,/\./g')\"" 
}

ascii_conv () {
  echo -e $1 | sed -e 's/\\u0000//g' -e 's/\\"//g'
}

operator_conv () {
  echo "\"$(echo $1 | sed -e 's/\"//' | awk '{print $1}')\""
}

read_modbus () {
  reg=$1
  size=$2
  type=$3
  conv=""
  if [ "${type}" = "ascii" ]; then
     conv="ascii_conv"
  elif [ "${type}" = "temp" ]; then
    type="32bit_int1234"
    conv="float_div_10"
  elif [ "${type}" = "ip" ]; then
    type="8bit_uint"
    conv="ip_conv"
  elif [ "${type}" = "operator" ]; then
    type="ascii"
    conv="operator_conv"
  fi
  #ret=$(modbus_tcp_test ${MODBUS_SERVER} ${MODBUS_PORT} 1 1 3 ${reg} ${size} ${type} 1)
  ret=$(ubus call modbus_master tcp.test "{\"ip\":\"${MODBUS_SERVER}\", \"port\":${MODBUS_PORT}, \"id\":1, \"timeout\":1, \"function\":3, \"first_reg\":${reg}, \"reg_count\":\"${size}\", \"data_type\":\"${type}\", \"no_brackets\":1}" | grep '"result"' | sed -e 's/.*"result"://') 
  ret=$(eval /bin/echo $ret)
  if [ -n "${conv}" ]; then
    ret=$(${conv} "${ret}")
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

