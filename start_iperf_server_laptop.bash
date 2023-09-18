#!/usr/bin/bash

vlan_start=100

echo "vlan_start:${vlan_start}"

devices=(pi4 pi3b jetson nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus2)
qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)

device_count=0
for device in "${devices[@]}"; do
	device_count=$((device_count + 1))

	qdisc_count=0
	for qdisc in "${qdiscs[@]}"; do
		qdisc_count=$((qdisc_count + 1))

		namespace=$(((device_count * vlan_start) + qdisc_count))

		echo "device:${device} qdisc:${qdisc} namespace:${namespace}"

		echo ip netns exec network"${namespace}" iperf --server --daemon --ipv6_domain
		ip netns exec network"${namespace}" iperf --server --daemon --ipv6_domain

	done

done

echo "started iperf server"
