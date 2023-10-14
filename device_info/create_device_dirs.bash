#!/usr/bin/bash

echo "Creating folders to store device info into"

readarray -t devices <../script_configuration/devices.txt
#devices=(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2)
echo "devices:${devices[*]}"

for device in "${devices[@]}"; do
	mkdir --parents "${device}"
done
