#!/usr/bin/bash

device=pi4
nic=eth0
device_count=1
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
