#!/usr/bin/bash

nic=eth0
x=101
qdisc="cake"
#bandwidth="1gbit"
bandwidth="100mbit"

if [[ -n $1 ]]; then
	qdisc=$1
fi

./cake_setup_routing_device.bash "${nic}" "${x}" "${qdisc}" "${bandwidth}"
