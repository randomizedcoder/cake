#!/usr/bin/bash

device=jetson
nic=eth0
device_count=3
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
