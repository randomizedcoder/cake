#!/usr/bin/bash

laptop=ryzen
nic=enp2s0f0

sudo /home/das/Downloads/cake/configure_device_scripts/qdisc_laptop.bash "${laptop}" "${nic}"
