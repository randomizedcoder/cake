#!/usr/bin/bash

commands=("apt update" "apt upgrade --yes" "apt autoremove")

devices=(pi4 pi3b jetson nanopi-neo3 nanopi-r5c asus2)

for device in "${devices[@]}"; do
	for command in "${commands[@]}"; do
		echo "device:${device} command:${command}"
		echo ssh -l root "${device}" \""${command}"\"
		ssh -l root "${device}" \""${command}"\"
	done
done
