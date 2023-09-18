#!/usr/bin/bash

device=nanopi_r1
nic=eth0
device_count=6
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
