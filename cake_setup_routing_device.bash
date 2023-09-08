#!/usr/bin/bash

nic=$1
x=$2
y=$((x + 100))
qdisc=$3
bandwidth=$4
rtt=$5

#-----------------------------------------------
# system setup

echo sysctl -w net.ipv4.ip_local_port_range="1025 65535"
sysctl -w net.ipv4.ip_local_port_range="1025 65535"

echo sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_timestamps=1

echo sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.ip_forward=1

echo sysctl -w net.core.default_qdisc="${qdisc}"
sysctl -w net.core.default_qdisc="${qdisc}"

case ${qdisc} in
pfifo_fast)
	# https://www.man7.org/linux/man-pages/man8/tc-pfifo_fast.8.html
	echo tc qdisc replace dev "${nic}" root pfifo_fast
	tc qdisc replace dev "${nic}" root pfifo_fast
	;;
cake)
	# https://www.man7.org/linux/man-pages/man8/tc-cake.8.html
	echo tc qdisc replace dev "${nic}" root cake ether-vlan bandwidth "${bandwidth}" rtt "${rtt}"
	tc qdisc replace dev "${nic}" root cake ether-vlan bandwidth "${bandwidth}" rtt "${rtt}"
	;;
fq_codel)
	# https://www.man7.org/linux/man-pages/man8/tc-fq_codel.8.html
	echo tc qdisc replace dev "${nic}" root fq_codel
	tc qdisc replace dev "${nic}" root fq_codel
	;;
fq)
	echo tc qdisc replace dev "${nic}" root fq
	tc qdisc replace dev "${nic}" root fq
	;;
noqueue)
	# https://www.man7.org/linux/man-pages/man8/tc-fq_codel.8.html
	echo tc qdisc replace dev "${nic}" root noqueue
	tc qdisc replace dev "${nic}" root noqueue
	;;
*)
	echo "unsupport qdisc"
	;;
esac

echo tc -s qdisc ls dev "${nic}"
tc -s qdisc ls dev "${nic}"

#-----------------------------------------------

echo "### Creating network namespace"
echo ip netns add network"${x}"
ip netns add network"${x}"

echo ip netns exec network"${x}" sysctl -w net.ipv4.ip_forward=1
ip netns exec network"${x}" sysctl -w net.ipv4.ip_forward=1

nets=("${x}" "${y}")
for net in "${nets[@]}"; do

	echo "### Creating vlan interface"
	echo ip link add link "${nic}" name "${nic}"."${net}" type vlan id "${net}"
	ip link add link "${nic}" name "${nic}"."${net}" type vlan id "${net}"

	echo "### Moving vlan interface to network namespace"
	echo ip link set dev "${nic}"."${net}" netns network"${x}"
	ip link set dev "${nic}"."${net}" netns network"${x}"

	echo "### Configure cake qdisc"
	case ${qdisc} in
	pfifo_fast)
		# https://www.man7.org/linux/man-pages/man8/tc-pfifo_fast.8.html
		echo ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root pfifo_fast
		ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root pfifo_fast
		;;
	cake)
		# https://www.man7.org/linux/man-pages/man8/tc-cake.8.html
		echo ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root cake ether-vlan bandwidth "${bandwidth}" rtt "${rtt}"
		ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root cake ether-vlan bandwidth "${bandwidth}" rtt "${rtt}"
		;;
	fq_codel)
		# https://www.man7.org/linux/man-pages/man8/tc-fq_codel.8.html
		echo ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root fq_codel
		ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root fq_codel
		;;
	fq)
		echo ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root fq
		ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root fq
		;;
	noqueue)
		echo ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root noqueue
		ip netns exec network"${x}" tc qdisc replace dev "${nic}"."${net}" root noqueue
		;;
	*)
		echo "unsupport qdisc"
		;;
	esac

	echo ip netns exec network"${x}" tc -s qdisc ls dev "${nic}"."${net}"
	ip netns exec network"${x}" tc -s qdisc ls dev "${nic}"."${net}"

	echo "### Configure ip address on vlan interface"
	echo ip netns exec network"${x}" ip address add 172.16."${net}".1/24 dev "${nic}"."${net}"
	ip netns exec network"${x}" ip address add 172.16."${net}".1/24 dev "${nic}"."${net}"

	echo "### Bring interface up"
	echo ip netns exec network"${x}" ip link set dev "${nic}"."${net}" up
	ip netns exec network"${x}" ip link set dev "${nic}"."${net}" up

done

echo "######### -----------------------"

echo ip netns exec network"${x}" ip link show
ip netns exec network"${x}" ip link show

echo "####"
echo ip netns exec network"${x}" ip addr show
ip netns exec network"${x}" ip addr show

echo "####"
echo ip netns exec network"${x}" ip route show
ip netns exec network"${x}" ip route show

for net in "${nets[@]}"; do

	echo "######### -----------------------"

	echo ip netns exec network"${x}" ping -c 3 -w 1 172.16."${net}".10
	ip netns exec network"${x}" ping -c 3 -w 1 172.16."${net}".10

done
