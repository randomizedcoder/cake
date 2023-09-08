#!/usr/bin/bash

sysctl -w net.core.default_qdisc=fq_codel
sysctl -w net.ipv4.ip_local_port_range="1025 65535"
sysctl -w net.ipv4.tcp_timestamps=1

nic=enp0s25
vlans=(100 101 102 103 104 105)

for x in "${vlans[@]}"; do
	y=$((x + 100))
	echo "x:${x}, y:${y}"

	echo ip link add link "${nic}" name "${nic}"."${y}" type vlan id "${y}"
	ip link add link "${nic}" name "${nic}"."${y}" type vlan id "${y}"

	echo ip netns add network"${y}"
	ip netns add network"${y}"

	echo ip link set dev "${nic}"."${y}" netns network"${y}"
	ip link set dev "${nic}"."${y}" netns network"${y}"

	echo ip netns exec network"${y}" ip link set dev "${nic}"."${y}" up
	ip netns exec network"${y}" ip link set dev "${nic}"."${y}" up

	echo ip netns exec network"${y}" ip address add 172.16."${y}".10/24 dev "${nic}"."${y}"
	ip netns exec network"${y}" ip address add 172.16."${y}".10/24 dev "${nic}"."${y}"

	echo ip netns exec network"${y}" ip route add 0.0.0.0/0 via 172.16."${y}".1
	ip netns exec network"${y}" ip route add 0.0.0.0/0 via 172.16."${y}".1
	#ip netns exec network"$y" ip route add 172.16."$x".0/24 via 172.16."$y".1

	nets=("${y}")
	for net in "${nets[@]}"; do

		echo ip netns exec network"${net}" sysctl -w net.ipv4.ip_local_port_range="1025 65535"
		ip netns exec network"${net}" sysctl -w net.ipv4.ip_local_port_range="1025 65535"

		echo ip netns exec network"${net}" sysctl -w net.ipv4.tcp_timestamps=1
		ip netns exec network"${net}" sysctl -w net.ipv4.tcp_timestamps=1

		echo ip netns exec network"${net}" sysctl net.ipv4.tcp_rmem="4096    1000000    16000000"
		ip netns exec network"${net}" sysctl net.ipv4.tcp_rmem="4096    1000000    16000000"

		echo ip netns exec network"${net}" sysctl net.ipv4.tcp_wmem="4096    1000000    16000000"
		ip netns exec network"${net}" sysctl net.ipv4.tcp_wmem="4096    1000000    16000000"

		echo ip netns exec network"${net}" sysctl net.ipv4.tcp_congestion_control=cubic
		ip netns exec network"${net}" sysctl net.ipv4.tcp_congestion_control=cubic

		echo ip netns exec network"${net}" tc qdisc replace dev "${nic}"."${net}" root fq_codel
		ip netns exec network"${net}" tc qdisc replace dev "${nic}"."${net}" root fq_codel

		echo ip netns exec network"${net}" tc -s qdisc ls dev "${nic}"."${net}"
		ip netns exec network"${net}" tc -s qdisc ls dev "${nic}"."${net}"

	done

	#
	# show
	#
	echo "--------------------------------show"

	echo ip netns exec network"${y}" ip link show
	ip netns exec network"${y}" ip link show

	echo ip netns exec network"${y}" ip addr show
	ip netns exec network"${y}" ip addr show

	echo ip netns exec network"${y}" ip route show
	ip netns exec network"${y}" ip route show

	#
	# ping test
	#
	echo "--------------------------------ping"
	count=5

	echo ip netns exec network"${y}" ping -w 1 -c "${count}" 172.16."${y}".1
	ip netns exec network"${y}" ping -w 1 -c "${count}" 172.16."${y}".1

	echo ip netns exec network"${y}" ping -w 1 -c "${count}" 172.16."${x}".1
	ip netns exec network"${y}" ping -w 1 -c "${count}" 172.16."${x}".1

done

ls /run/netns/network*
