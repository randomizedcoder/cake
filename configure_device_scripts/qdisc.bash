#!/usr/bin/bash
#
# This script just calls the device specific script to configure the qdisc-s

my_hostname=$(hostname)
echo "my_hostname:${my_hostname}"

if [[ -f "/home/das/qdisc_${my_hostname}.bash" ]]; then
	cd /home/das/ || true
	echo /home/das/qdisc_"${my_hostname}".bash
	/home/das/qdisc_"${my_hostname}".bash
fi

if [[ -f "/home/das/Downloads/cake/configure_device_scripts/qdisc_${my_hostname}.bash" ]]; then
	cd /home/das/Downloads/cake || true
	echo /home/das/Downloads/cake/configure_device_scripts/qdisc_"${my_hostname}".bash
	/home/das/Downloads/cake/configure_device_scripts/qdisc_"${my_hostname}".bash
fi
