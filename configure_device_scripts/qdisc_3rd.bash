#!/usr/bin/bash

laptop=3rd
nic=enp0s25

sudo /home/das/Downloads/cake/configure_device_scripts/qdisc_laptop.bash "${laptop}" "${nic}"
