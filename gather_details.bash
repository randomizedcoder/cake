#!/usr/bin/bash

commands=("cat /proc/cpuinfo" "cat /proc/meminfo" "cat /proc/interrupts" "cat /proc/net/dev" "uname -a" "cat /etc/lsb-release")

#dir=${PWD}

for command in "${commands[@]}"; do
	ansible all -m "${command}" -u root
done
