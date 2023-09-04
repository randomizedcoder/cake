#!/usr/bin/bash

nic=enp1s0
x=105
qdisc="cake"
bandwidth="1gbit"
#"100mbit"

if [[ -n $1 ]]; then
	qdisc=$1
fi

./cake_setup_routing_device.bash "${nic}" "${x}" "${qdisc}" "${bandwidth}"
