#!/usr/bin/bash

nic=eth0
x=101
qdisc="cake"
#bandwidth="1gbit"
bandwidth="100mbit"
rtt="3ms"

if [[ -n $1 ]]; then
	qdisc=$1
fi

if [[ -n $2 ]]; then
	rtt=$2
fi

./cake_setup_routing_device.bash "${nic}" "${x}" "${qdisc}" "${bandwidth}" "${rtt}"
