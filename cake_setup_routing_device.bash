#!/usr/bin/bash

device=$1
nic=$2
device_count=$3
bandwidth=$4

subnet_octet_a=172
subnet_octet_b=16

vlan_start=100
vlan_addition=50

# sub interface names are apparently limited to 11 chars
vlan_dev=${nic:0:11}

#-----------------------------------------------
# system setup

echo sysctl -w net.ipv4.ip_local_port_range="1025 65535"
sysctl -w net.ipv4.ip_local_port_range="1025 65535"

echo sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_timestamps=1

echo sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.ip_forward=1

echo sysctl -w net.core.default_qdisc="pfifo_fast"
sysctl -w net.core.default_qdisc="pfifo_fast"

qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)

qdisc_count=0
for qdisc in "${qdiscs[@]}"; do
	qdisc_count=$((qdisc_count + 1))

	namespace=$(((device_count * vlan_start) + qdisc_count))

	vlan="${namespace}"

	octet_a="${subnet_octet_a}"
	octet_b=$((subnet_octet_b + device_count))
	octet_c=$((qdisc_count))

	#-----------------------------------------------

	echo "### Creating network namespace:network${namespace}"
	echo ip netns add network"${namespace}"
	ip netns add network"${namespace}"

	echo ip netns exec network"${namespace}" sysctl -w net.ipv4.ip_forward=1
	ip netns exec network"${namespace}" sysctl -w net.ipv4.ip_forward=1

	nets=(x y)
	net_count=0
	for _ in "${nets[@]}"; do
		net_count=$((net_count + 1))

		if [[ ${net_count} == 2 ]]; then
			vlan=$((vlan + vlan_addition))
			octet_c=$((octet_c + vlan_addition))
		fi

		octet_d=1

		#echo "device:$device qdisc:$qdisc vlan:$vlan octet_a:$octet_a octet_b:$octet_b octet_c:$octet_c octet_d:$octet_d"

		echo "device:${device} qdisc:${qdisc} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

		echo "### Creating vlan interface"
		echo ip link add link "${nic}" name "${vlan_dev}"."${vlan}" type vlan id "${vlan}"
		ip link add link "${nic}" name "${vlan_dev}"."${vlan}" type vlan id "${vlan}"

		echo "### Moving vlan interface to network namespace"
		echo ip link set dev "${vlan_dev}"."${vlan}" netns network"${namespace}"
		ip link set dev "${vlan_dev}"."${vlan}" netns network"${namespace}"

		#----------------------

		echo "### Configure cake qdisc"
		case ${qdisc} in
		noqueue)
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root noqueue
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root noqueue
			;;
		pfifo_fast)
			# https://www.man7.org/linux/man-pages/man8/tc-pfifo_fast.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root pfifo_fast
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root pfifo_fast
			;;
		fq)
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq
			;;
		fq_codel)
			# https://www.man7.org/linux/man-pages/man8/tc-fq_codel.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq_codel
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq_codel
			;;
		cake20)
			# https://www.man7.org/linux/man-pages/man8/tc-cake.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 20ms
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 20ms
			;;
		cake40)
			# https://www.man7.org/linux/man-pages/man8/tc-cake.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 40ms
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 40ms
			;;
		*)
			echo "unsupport qdisc"
			;;
		esac

		echo ip netns exec network"${namespace}" tc -s qdisc ls dev "${vlan_dev}"."${vlan}"
		ip netns exec network"${namespace}" tc -s qdisc ls dev "${vlan_dev}"."${vlan}"

		echo "### Configure ip address on vlan interface"
		echo ip netns exec network"${namespace}" ip address add "${octet_a}"."${octet_b}"."${octet_c}"."${octet_d}"/24 dev "${vlan_dev}"."${vlan}"
		ip netns exec network"${namespace}" ip address add "${octet_a}"."${octet_b}"."${octet_c}"."${octet_d}"/24 dev "${vlan_dev}"."${vlan}"

		echo "### Bring interface up"
		echo ip netns exec network"${namespace}" ip link set dev "${vlan_dev}"."${vlan}" up
		ip netns exec network"${namespace}" ip link set dev "${vlan_dev}"."${vlan}" up

		echo "######### -----------------------"

		echo ip netns exec network"${namespace}" ping -c 3 -w 1 ${octet_a}.${octet_b}.${octet_c}.10

	done

	echo "######### -----------------------"

	echo ip netns exec network"${namespace}" ip link show
	ip netns exec network"${namespace}" ip link show

	echo "####"
	echo ip netns exec network"${namespace}" ip addr show
	ip netns exec network"${namespace}" ip addr show

	echo "####"
	echo ip netns exec network"${namespace}" ip route show
	ip netns exec network"${namespace}" ip route show

done

echo find /run/netns/
find /run/netns/

echo find /run/netns/ | wc -l
find /run/netns/ | wc -l
