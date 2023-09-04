#!/usr/bin/bash

sysctl -w net.core.default_qdisc=cake
sysctl -w net.ipv4.ip_local_port_range="1025 65535"
sysctl -w net.ipv4.tcp_timestamps=1

nic=enp0s25
vlans=(100 101 102 103 104 105)

for x in "${vlans[@]}"; do
	y=$((x + 100))
	echo "x:${x}, y:${y}"

	echo ip link add link "${nic}" name "${nic}"."${x}" type vlan id "${x}"
	ip link add link "${nic}" name "${nic}"."${x}" type vlan id "${x}"

	echo ip netns add network"${x}"
	ip netns add network"${x}"

	echo ip link set dev "${nic}"."${x}" netns network"${x}"
	ip link set dev "${nic}"."${x}" netns network"${x}"

	echo ip netns exec network"${x}" ip link set dev "${nic}"."${x}" up
	ip netns exec network"${x}" ip link set dev "${nic}"."${x}" up

	echo ip netns exec network"${x}" ip address add 172.16."${x}".10/24 dev "${nic}"."${x}"
	ip netns exec network"${x}" ip address add 172.16."${x}".10/24 dev "${nic}"."${x}"

	echo ip netns exec network"${x}" ip route add 0.0.0.0/0 via 172.16."${x}".1
	ip netns exec network"${x}" ip route add 0.0.0.0/0 via 172.16."${x}".1
	#ip netns exec network"$x" ip route add 172.16."$y".0/24 via 172.16."$x".1

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

	nets=(100 101)
	for net in "${nets[@]}"; do
		echo ip netns exec network"${net}" sysctl -w net.core.default_qdisc=fq_codel
		ip netns exec network"${net}" sysctl -w net.core.default_qdisc=fq_codel

		echo ip netns exec network"${net}" sysctl -w net.ipv4.ip_local_port_range="1025 65535"
		ip netns exec network"${net}" sysctl -w net.ipv4.ip_local_port_range="1025 65535"

		echo ip netns exec network"${net}" sysctl -w net.ipv4.tcp_timestamps=1
		ip netns exec network"${net}" sysctl -w net.ipv4.tcp_timestamps=1

		echo tc qdisc replace dev "${nic}"."${net}" root fq_codel
		tc qdisc replace dev "${nic}"."${net}" root fq_codel

		echo tc -s qdisc ls dev "${nic}"."${net}"
		tc -s qdisc ls dev "${nic}"."${net}"
	done

	#
	# show
	#
	echo "--------------------------------show"

	echo ip netns exec network"${x}" ip link show
	ip netns exec network"${x}" ip link show

	echo ip netns exec network"${x}" ip addr show
	ip netns exec network"${x}" ip addr show

	echo ip netns exec network"${x}" ip route show
	ip netns exec network"${x}" ip route show

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

	echo ip netns exec network"${x}" ping -w 1 -c 2 172.16."${x}".1
	ip netns exec network"${x}" ping -w 1 -c 2 172.16."${x}".1

	echo ip netns exec network"${x}" ping -w 1 -c 2 172.16."${y}".1
	ip netns exec network"${x}" ping -w 1 -c 2 172.16."${y}".1

	echo ip netns exec network"${y}" ping -w 1 -c 2 172.16."${y}".1
	ip netns exec network"${y}" ping -w 1 -c 2 172.16."${y}".1

	echo ip netns exec network"${y}" ping -w 1 -c 2 172.16."${x}".1
	ip netns exec network"${y}" ping -w 1 -c 2 172.16."${x}".1

done
