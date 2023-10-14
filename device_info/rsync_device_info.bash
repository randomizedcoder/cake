#!/usr/bin/bash

readarray -t devices <../script_configuration/devices.txt
#devices=(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2)
echo "devices:${devices[*]}"

echo "## Rsyncing device_info"

output_folder=/tmp/device_info/

for device in "${devices[@]}"; do
	echo "device:${device}"
	echo /usr/bin/rsync -av "${device}:${output_folder}" ./"${device}"/
	/usr/bin/rsync -a "${device}:${output_folder}" ./"${device}"/
done
