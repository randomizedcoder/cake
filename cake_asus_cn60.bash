#!/usr/bin/bash

device=asus_cn60
nic=enp1s0
device_count=7
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
