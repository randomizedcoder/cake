#!/usr/bin/bash

readarray -t laptops <./script_configuration/laptops.txt
echo "laptops:${laptops[*]}"
for laptop in "${laptops[@]}"; do

	echo "## Copy files to laptop:${laptop}"
	scp ./configure_device_scripts/qdisc_"${laptop}".bash "${laptop}":
	scp ./configure_device_scripts/qdisc_laptop.bash "${laptop}":

	echo "## Rsyncing cake directory to laptop:${laptop}"
	echo rsync -davz --exclude '.git' ./ "${laptop}":/home/das/Downloads/cake/
	rsync -davz --exclude '.git' ./ "${laptop}":/home/das/Downloads/cake/

done

echo "## Copy ansible config"
echo scp ./ansible/ansible.cfg 3rd:.ansible.cfg
scp ./ansible/ansible.cfg 3rd:.ansible.cfg

readarray -t devices <./script_configuration/devices.txt
#devices=(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2)
echo "devices:${devices[*]}"

for device in "${devices[@]}"; do

	echo "## Copying device specific configuration:${device}"
	echo scp ./configure_device_scripts/qdisc_"${device}".bash "${device}":
	scp ./configure_device_scripts/qdisc_"${device}".bash "${device}":

	echo "## Copying generic configuration script to:${device}"
	echo scp ./configure_device_scripts/qdisc_setup_routing_device.bash "${device}":
	scp ./configure_device_scripts/qdisc_setup_routing_device.bash "${device}":

	echo scp ./configure_device_scripts/qdisc.bash "${device}":
	scp ./configure_device_scripts/qdisc.bash "${device}":

done
