#!/usr/bin/bash

readarray -t devices <../script_configuration/devices.txt
#devices=(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2)
echo "devices:${devices[*]}"

echo "## FPing devices"
for device in "${devices[@]}"; do
	echo "device:${device}"
	echo fping "${device}"
	fping "${device}"
done

echo "## Ping devices"
for device in "${devices[@]}"; do
	echo "device:${device}"
	echo ping -c 3 -w 1 "${device}"
	ping -c 3 -w 1 "${device}"
done
