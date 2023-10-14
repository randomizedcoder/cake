#!/usr/bin/bash

device=$1
device_count=$2

bandwidth="950mbit"
if [[ -n $3 ]]; then
	bandwidth=$3
fi

if [[ -n $4 ]]; then
	qdisc_to_set=$4
fi

subnet_octet_a=172
subnet_octet_b=16

vlan_start=100
vlan_addition=50

#------------------------------
# Find the default route interface
#ip route show default
#default via 172.16.50.1 dev wlp0s20f3 proto dhcp src 172.16.50.140 metric 600
default_route_line=$(ip route show default)
#echo "default_route_line:${default_route_line}"
regex="dev\s+(\S+)"
if [[ ${default_route_line} =~ ${regex} ]]; then
	default_route_interface="${BASH_REMATCH[1]}"
fi
echo "default_route_interface:${default_route_interface}"
nic="${default_route_interface}"

# sub interface names are apparently limited to 11 chars
vlan_dev=${nic:0:11}

#-----------------------------------------------
# system setup

echo sysctl -w net.ipv4.ip_local_port_range="1025 65534"
sysctl -w net.ipv4.ip_local_port_range="1025 65534"

echo sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_timestamps=1

echo sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.ip_forward=1

echo sysctl -w net.core.default_qdisc="pfifo_fast"
sysctl -w net.core.default_qdisc="pfifo_fast"

qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)
namespaces=()

qdisc_count=0
for qdisc in "${qdiscs[@]}"; do
	qdisc_count=$((qdisc_count + 1))

	if [[ -n ${qdisc_to_set} ]]; then
		if [[ ${qdisc} != "${qdisc_to_set}" ]]; then
			continue
		fi
	fi

	namespace=$(((device_count * vlan_start) + qdisc_count))
	namespaces+=("${namespace}")

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

		echo "#----------------------------------------------- ${device} ${qdisc}"
		echo "device:${device} qdisc:${qdisc} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

		echo "### Creating vlan interface"
		echo ip link add link "${nic}" name "${vlan_dev}"."${vlan}" type vlan id "${vlan}"
		ip link add link "${nic}" name "${vlan_dev}"."${vlan}" type vlan id "${vlan}"

		echo "### Moving vlan interface to network namespace"
		echo ip link set dev "${vlan_dev}"."${vlan}" netns network"${namespace}"
		ip link set dev "${vlan_dev}"."${vlan}" netns network"${namespace}"

		#----------------------
		# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/linux-traffic-control_configuring-and-managing-networking

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
			# https://linuxnet-qos.readthedocs.io/en/latest/qdiscs/fq_codel.html
			# flows default is 1024
			# memory_limit default is 32MB
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq_codel flows 4096 memory_limit 64MB
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq_codel flows 4096 memory_limit 64MB
			;;
		cake20)
			# https://www.man7.org/linux/man-pages/man8/tc-cake.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 20ms ack-filter
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 20ms ack-filter
			;;
		cake40)
			# https://www.man7.org/linux/man-pages/man8/tc-cake.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 40ms ack-filter
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root cake ether-vlan bandwidth "${bandwidth}" rtt 40ms ack-filter
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

		echo ip netns exec network"${namespace}" ping -c 3 -w 1 "${octet_a}.${octet_b}.${octet_c}".10

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

echo "######### -----------------------"
echo find /run/netns/
find /run/netns/

echo find /run/netns/ | wc -l || true
find /run/netns/ | wc -l || true

echo "######### -----------------------"
for ns in "${namespaces[@]}"; do
	echo ip netns exec network"${ns}" ip route show
	ip netns exec network"${ns}" ip route show
done
