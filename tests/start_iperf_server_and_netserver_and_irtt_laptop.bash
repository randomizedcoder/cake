#!/usr/bin/bash

who_am_i=$(whoami)

if [[ ${who_am_i} != "root" ]]; then
	echo "must be root"
	exit 1
fi

vlan_start=100
vlan_addition=50
echo "vlan_start:${vlan_start}"
echo "vlan_addition:${vlan_addition}"

echo "## killing any existing iperf servers"
echo killall iperf
killall iperf

echo "## killing any existing netserver servers"
echo killall netserver
killall netserver

echo cd /home/das/cake/ || exit
cd /home/das/cake/ || exit

readarray -t devices </home/das/Downloads/cake/script_configuration/devices.txt
#devices=(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2)
echo "devices:${devices[*]}"

readarray -t qdiscs </home/das/Downloads/cake/script_configuration/qdiscs.txt
#qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)
echo "qdiscs:${qdiscs[*]}"

device_count=0
for device in "${devices[@]}"; do
	device_count=$((device_count + 1))

	qdisc_count=0
	for qdisc in "${qdiscs[@]}"; do
		qdisc_count=$((qdisc_count + 1))

		namespace=$(((device_count * vlan_start) + qdisc_count))

		echo "device:${device} qdisc:${qdisc} namespace:${namespace}"

		echo ip netns exec network"${namespace}" nice -20 iperf --server --daemon --ipv6_domain
		ip netns exec network"${namespace}" nice -20 iperf --server --daemon --ipv6_domain

		# https://flent.org/intro.html#quick-start
		echo ip netns exec network"${namespace}" nice -20 netserver \&
		ip netns exec network"${namespace}" nice -20 netserver &

		echo ip netns exec network"${namespace}" nice -20 irtt server \&
		ip netns exec network"${namespace}" nice -20 irtt server &

	done

done

processes=(iperf netserver)
for process in "${processes[@]}"; do
	echo ps ax | grep "${process}"
	ps ax | grep "${process}"
done

for process in "${processes[@]}"; do
	echo ps ax | grep -c "${process}"
	ps ax | grep -c "${process}"
done

echo "started iperf server and netserver"
