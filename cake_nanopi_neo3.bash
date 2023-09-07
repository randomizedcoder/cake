#!/usr/bin/bash

nic=end0
x=103
qdisc="cake"
bandwidth="1gbit"
#"100mbit"

if [[ -n $1 ]]; then
	qdisc=$1
fi

./cake_setup_routing_device.bash "${nic}" "${x}" "${qdisc}" "${bandwidth}"
