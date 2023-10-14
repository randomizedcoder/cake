#!/usr/bin/bash

laptop=$1
echo "laptop:${laptop}"

nic=$2
echo "nic:${nic}"

netem_delay="20ms"

case ${laptop} in
3rd)
	echo "laptop 3rd"
	;;
ryzen)
	echo "laptop ryzen"
	;;
*)
	echo 'Please pass "3rd" or "ryzen"'
	exit 1
	;;
esac

sysctl -w net.core.default_qdisc=fq_codel
sysctl -w net.ipv4.ip_local_port_range="1025 65534"
sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_fin_timeout=10

ping_count=5
ping_Wtimeout=0.5

# sub interface names are apparently limited to 11 chars
vlan_dev=${nic:0:11}
echo "vlan_dev${vlan_dev}"

subnet_octet_a=172
subnet_octet_b=16

vlan_start=100
vlan_addition=50

ping_retries=0

echo "subnet_octet_a:${subnet_octet_a}"
echo "subnet_octet_b:${subnet_octet_b}"
echo "vlan_start:${vlan_start}"
echo "vlan_addition:${vlan_addition}"

readarray -t devices </home/das/Downloads/cake/script_configuration/devices.txt
#devices=(pi4 pi3b jetson nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus2)

readarray -t qdiscs </home/das/Downloads/cake/script_configuration/qdiscs.txt
#qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)

device_count=0
for device in "${devices[@]}"; do
	device_count=$((device_count + 1))

	qdisc_count=0
	for qdisc in "${qdiscs[@]}"; do
		qdisc_count=$((qdisc_count + 1))

		namespace=$(((device_count * vlan_start) + qdisc_count))

		vlan="${namespace}"

		octet_a="${subnet_octet_a}"
		octet_b=$((subnet_octet_b + device_count))
		octet_c=$((qdisc_count))

		nets=(x y)
		net_count=0
		for _ in "${nets[@]}"; do
			net_count=$((net_count + 1))

			case ${laptop} in
			3rd)
				echo "laptop 3rd"
				if [[ ${net_count} == 2 ]]; then
					echo "config complete"
					continue
				fi
				;;
			ryzen)
				echo "laptop ryzen"
				if [[ ${net_count} == 1 ]]; then
					echo "skipping 1st network"
					continue
				fi
				;;
			*)
				echo 'Please pass "3rd" or "ryzen"'
				exit 1
				;;
			esac

			if [[ ${net_count} == 2 ]]; then
				vlan=$((vlan + vlan_addition))
				octet_c=$((octet_c + vlan_addition))
			fi

			octet_d=10

			#echo "device:$device qdisc:$qdisc vlan:$vlan octet_a:$octet_a octet_b:$octet_b octet_c:$octet_c octet_d:$octet_d"

			echo "#----------------------------------------------- ${device} ${qdisc}"
			echo "device:${device} qdisc:${qdisc} namespace:${namespace} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

			echo ip netns add network"${namespace}"
			ip netns add network"${namespace}"

			echo "### Creating vlan interface"
			echo ip link add link "${nic}" name "${vlan_dev}"."${vlan}" type vlan id "${vlan}"
			ip link add link "${nic}" name "${vlan_dev}"."${vlan}" type vlan id "${vlan}"

			echo "### Moving vlan interface to network namespace"
			echo ip link set dev "${vlan_dev}"."${vlan}" netns network"${namespace}"
			ip link set dev "${vlan_dev}"."${vlan}" netns network"${namespace}"

			echo ip netns exec network"${namespace}" ip link set dev "${vlan_dev}"."${vlan}" up
			ip netns exec network"${namespace}" ip link set dev "${vlan_dev}"."${vlan}" up

			echo "### Configure ip address on vlan interface"
			echo ip netns exec network"${namespace}" ip address add "${octet_a}"."${octet_b}"."${octet_c}"."${octet_d}"/24 dev "${vlan_dev}"."${vlan}"
			ip netns exec network"${namespace}" ip address add "${octet_a}"."${octet_b}"."${octet_c}"."${octet_d}"/24 dev "${vlan_dev}"."${vlan}"

			echo "### Configure default route"
			echo ip netns exec network"${namespace}" ip route add 0.0.0.0/0 via "${octet_a}"."${octet_b}"."${octet_c}".1
			ip netns exec network"${namespace}" ip route add 0.0.0.0/0 via "${octet_a}"."${octet_b}"."${octet_c}".1

			echo "### Configure sysctls"
			echo ip netns exec network"${namespace}" sysctl -w net.ipv4.ip_local_port_range="1025 65534"
			ip netns exec network"${namespace}" sysctl -w net.ipv4.ip_local_port_range="1025 65534"

			echo ip netns exec network"${namespace}" sysctl -w net.ipv4.tcp_timestamps=1
			ip netns exec network"${namespace}" sysctl -w net.ipv4.tcp_timestamps=1

			echo ip netns exec network"${namespace}" sysctl net.ipv4.tcp_rmem="4096    1000000    16000000"
			ip netns exec network"${namespace}" sysctl net.ipv4.tcp_rmem="4096    1000000    16000000"

			echo ip netns exec network"${namespace}" sysctl net.ipv4.tcp_wmem="4096    1000000    16000000"
			ip netns exec network"${namespace}" sysctl net.ipv4.tcp_wmem="4096    1000000    16000000"

			echo ip netns exec network"${namespace}" sysctl net.ipv4.tcp_congestion_control=cubic
			ip netns exec network"${namespace}" sysctl net.ipv4.tcp_congestion_control=cubic

			echo ip netns exec network"${namespace}" sysctl -w net.ipv4.tcp_timestamps=1
			ip netns exec network"${namespace}" sysctl -w net.ipv4.tcp_timestamps=1

			echo ip netns exec network"${namespace}" sysctl -w net.ipv4.tcp_fin_timeout=10
			ip netns exec network"${namespace}" sysctl -w net.ipv4.tcp_fin_timeout=10

			# echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq_codel
			# ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root fq_codel

			# https://www.man7.org/linux/man-pages/man8/tc-netem.8.html
			echo ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root handle 1 netem delay "${netem_delay}" limit 100000
			ip netns exec network"${namespace}" tc qdisc replace dev "${vlan_dev}"."${vlan}" root handle 1 netem delay "${netem_delay}" limit 100000

			echo ip netns exec network"${namespace}" tc -s qdisc ls dev "${vlan_dev}"."${vlan}"
			ip netns exec network"${namespace}" tc -s qdisc ls dev "${vlan_dev}"."${vlan}"

			echo "### View config"
			echo ip netns exec network"${namespace}" ip link show
			ip netns exec network"${namespace}" ip link show

			echo ip netns exec network"${namespace}" ip addr show
			ip netns exec network"${namespace}" ip addr show

			echo ip netns exec network"${namespace}" ip route show
			ip netns exec network"${namespace}" ip route show

			echo "BEFORE PING device:${device} qdisc:${qdisc} namespace:${namespace} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

			# this sleep seems to make the ping more successful.  why? no idea
			echo "sleep 1"
			sleep 1

			echo ip netns exec network"${namespace}" ping -W "${ping_Wtimeout}" -c "${ping_count}" "${octet_a}"."${octet_b}"."${octet_c}".1
			ip netns exec network"${namespace}" ping -W "${ping_Wtimeout}" -c "${ping_count}" "${octet_a}"."${octet_b}"."${octet_c}".1

			ping_result=$?

			if [[ ${laptop} == "3rd" ]]; then

				if [[ ${ping_result} != 0 ]]; then

					echo "#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
					echo "# ping failed!!"
					echo "device:${device} qdisc:${qdisc} namespace:${namespace} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

					echo "Retrying...."
					echo ip netns exec network"${namespace}" ping -W "${ping_Wtimeout}" -c "${ping_count}" "${octet_a}"."${octet_b}"."${octet_c}".1
					ip netns exec network"${namespace}" ping -W "${ping_Wtimeout}" -c "${ping_count}" "${octet_a}"."${octet_b}"."${octet_c}".1

					ping_result=$?

					ping_retries=${ping_retries}+1

					if [[ ${ping_result} != 0 ]]; then
						echo "Retrying failed :("
						exit 1
					else
						echo "#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
						echo "# retry successeded. ??!!"
					fi
				fi
			fi

		done

	done

done

echo "ping retries:${ping_retries}"

echo find /run/netns/
find /run/netns/

echo find /run/netns/ | wc -l || true
find /run/netns/ | wc -l || true
