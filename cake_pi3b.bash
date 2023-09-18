#!/usr/bin/bash

device=pi3b
nic=enxb827eb7039cb
device_count=2
#bandwidth="1gbit"
bandwidth="100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
