#!/usr/bin/bash

device=nanopi_r2s
nic=end0
device_count=5
bandwidth="1gbit"
#"100mbit"

./cake_setup_routing_device.bash "${device}" "${nic}" "${device_count}" "${bandwidth}"
