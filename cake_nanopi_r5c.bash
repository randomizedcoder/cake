#!/usr/bin/bash

device=nanopi_r5c
nic=eth0
device_count=4
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
