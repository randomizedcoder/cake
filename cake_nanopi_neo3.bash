#!/usr/bin/bash

device=nanopi_neo3
nic=end0
device_count=3
qdisc="cake"
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
