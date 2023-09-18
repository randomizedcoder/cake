#!/usr/bin/bash

interval=30
run_time=600
parallel=20

if [[ -n $1 ]]; then
	interval=$1
fi

if [[ -n $2 ]]; then
	run_time=$2
fi

if [[ -n $3 ]]; then
	parallel=$3
fi

timestamp=$(date +"%Y_%m_%d_%H:%M:%S")
#timestamp=$(date +"%Y_%m_%d_%H:%M:%S.%N")

echo mkdir "output_${timestamp}"
mkdir "output_${timestamp}"

subnet_octet_a=172
subnet_octet_b=16

vlan_start=100
vlan_addition=50

echo "subnet_octet_a:${subnet_octet_a}"
echo "subnet_octet_b:${subnet_octet_b}"
echo "vlan_start:${vlan_start}"
echo "vlan_addition:${vlan_addition}"

devices=(pi4 pi3b jetson nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus2)
qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)

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

			if [[ ${net_count} == 1 ]]; then
				echo "skipping 1st network"
				continue
			fi

			if [[ ${net_count} == 2 ]]; then
				vlan=$((vlan + vlan_addition))
				octet_c=$((octet_c + vlan_addition))
			fi

			octet_d=10

			#echo "device:$device qdisc:$qdisc vlan:$vlan octet_a:$octet_a octet_b:$octet_b octet_c:$octet_c octet_d:$octet_d"

			echo "#---------------------------------------------------------------"
			date +"%Y_%m_%d_%H:%M:%S"
			echo "device:${device} qdisc:${qdisc} namespace:${namespace} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

			start_time=$(date +"%Y_%m_%d_%H:%M:%S")

			ip netns exec network"${namespace}" \
				iperf \
				--client ${octet_a}.${octet_b}.${octet_c}.${octet_d} \
				--interval "${interval}" \
				--time "${run_time}" \
				--parallel "${parallel}" \
				--dualtest \
				--enhanced \
				--output "output_${timestamp}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${interval}_t_${run_time}_p_${parallel}_ts_${start_time}" \
				--sum-only

			date +"%Y_%m_%d_%H:%M:%S"

		done

	done

done

echo "iperf tests complete"
