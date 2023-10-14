#!/usr/bin/bash

set -e

gather_details_for_tests_from_devices() {
	device=$1
	qdisc=$2
	# stage is "before" or "after"
	stage=$3
	timestamp=$4

	dir="test_device_${device}_qdisc_${qdisc}_${stage}/"

	echo "## gathering networks stats from device:${device} stage:${stage}"
	echo ansible "${device}" -i ./ansible/ansible_hosts --become -m script -a "./gather_details_for_tests.bash /tmp/${dir}"
	ansible "${device}" -i ./ansible/ansible_hosts --become -m script -a "./gather_details_for_tests.bash /tmp/${dir}"
	date --utc +"## After gather_details_for_tests %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

	echo mkdir "/tmp/output_${timestamp}/${dir}"
	mkdir "/tmp/output_${timestamp}/${dir}"

	echo ls -la "/tmp/output_${timestamp}/${dir}"
	ls -la "/tmp/output_${timestamp}/${dir}"
	echo ssh "${device}" "ls -la /tmp/${dir}"
	ssh "${device}" "ls -la /tmp/${dir}"

	echo "## copy network stats to the test output directory, device:${device} stage:${stage}"
	## MUST USE trust sender!!!
	echo rsync -avz --trust-sender "${device}:/tmp/${dir}" "/tmp/output_${timestamp}/${dir}"
	rsync -avz --trust-sender "${device}:/tmp/${dir}" "/tmp/output_${timestamp}/${dir}"
	date --utc +"## After rsycnced stats %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

}

gather_details_for_tests_from_laptops() {
	device=$1
	qdisc=$2
	# stage is "before" or "after"
	stage=$3
	timestamp=$4

	laptops=(3rd ryzen)
	for laptop in "${laptops[@]}"; do

		dir="test_laptop_${laptop}_device_${device}_qdisc_${qdisc}_${stage}/"

		echo "## gathering networks stats from laptop:${laptop} stage:${stage}"

		echo ansible "${laptop}" -i ./ansible/ansible_hosts --become -m script -a "./gather_details_for_tests.bash /tmp/${dir}"
		ansible "${laptop}" -i ./ansible/ansible_hosts --become -m script -a "./gather_details_for_tests.bash /tmp/${dir}"
		date --utc +"## After gather_details_for_tests %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

		echo mkdir "/tmp/output_${timestamp}/${dir}"
		mkdir "/tmp/output_${timestamp}/${dir}"

		echo ls -la "/tmp/output_${timestamp}/${dir}"
		ls -la "/tmp/output_${timestamp}/${dir}"
		echo ssh "${laptop}" "ls -la /tmp/${dir}"
		ssh "${laptop}" "ls -la /tmp/${dir}"

		echo "## copy network stats to the test output directory, laptop:${laptop} stage:${stage}"
		## MUST USE trust sender!!!
		echo rsync -avz --trust-sender "${laptop}:/tmp/${dir}" "/tmp/output_${timestamp}/${dir}"
		rsync -avz --trust-sender "${laptop}:/tmp/${dir}" "/tmp/output_${timestamp}/${dir}"
		date --utc +"## After rsycnced stats %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

	done
}

iperf_interval=30
# 1 minute - recommended for testing this script
#run_time=60
#run_time=120
#10 minutes - recommended for testing
run_time=600
parallel=20

if [[ -n $1 ]]; then
	iperf_interval=$1
fi

if [[ -n $2 ]]; then
	run_time=$2
fi

if [[ -n $3 ]]; then
	parallel=$3
fi

timestamp=$(date --utc +"%Y_%m_%d_%H:%M:%S")
echo "timestamp:${timestamp}"
#timestamp=$(date --utc +"%Y_%m_%d_%H:%M:%S.%N")
test_start_secs=$(date --utc +%s)
echo "test_start_secs:${test_start_secs}"

subnet_octet_a=172
subnet_octet_b=16

vlan_start=100
vlan_addition=50

echo "subnet_octet_a:${subnet_octet_a}"
echo "subnet_octet_b:${subnet_octet_b}"
echo "vlan_start:${vlan_start}"
echo "vlan_addition:${vlan_addition}"

readarray -t devices <./device_info/devices.txt
#devices=(pi4 pi3b jetson-nano nanopi-neo3 nanopi-r5c nanopi-r2s nanopi-r1 asus-cn60-2)
# fix me - temp for testing
#devices=(pi4)
echo "## devices:${devices[*]}"

qdiscs=(noqueue pfifo_fast fq fq_codel cake20 cake40)
#fix me - temp for testing
#qdiscs=(noqueue pfifo_fast fq_codel)
echo "## qdiscs:${qdiscs[*]}"

laptops=(3rd ryzen)
echo "## laptops:${laptops[*]}"

echo "cd /home/das/cake/ || exit"
cd /home/das/cake/ || exit

echo mkdir "/tmp/output_${timestamp}"
mkdir "/tmp/output_${timestamp}"

for device in "${devices[@]}"; do
	echo mkdir "/tmp/output_${timestamp}/${device}"
	mkdir "/tmp/output_${timestamp}/${device}"
done

device_count=0
device_last=""
qdisc_last=""
for device in "${devices[@]}"; do
	device_count=$((device_count + 1))

	if [[ ${device_last} != "${device}" ]]; then
		device_start_secs=$(date --utc +%s)
		echo "## ---------------------------------"
		echo "## device_start_secs:${device_start_secs}"
		device_last="${device}"
	fi

	qdisc_count=0
	for qdisc in "${qdiscs[@]}"; do
		qdisc_count=$((qdisc_count + 1))

		if [[ ${qdisc_last} != "${qdisc}" ]]; then
			qdisc_start_secs=$(date --utc +%s)
			echo "## -----------------"
			echo "## qdisc_start_secs:${qdisc_start_secs}"
			qdisc_last="${qdisc}"
		fi

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
				echo "## skipping 1st network, because the iperf and netserver are running on 2nd network only"
				continue
			fi

			if [[ ${net_count} == 2 ]]; then
				vlan=$((vlan + vlan_addition))
				octet_c=$((octet_c + vlan_addition))
			fi

			octet_d=10

			#echo "device:$device qdisc:$qdisc vlan:$vlan octet_a:$octet_a octet_b:$octet_b octet_c:$octet_c octet_d:$octet_d"

			echo "#---------------------------------------------------------------"
			date --utc +"## Starting a test cycle %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"
			echo "##device:${device} qdisc:${qdisc} namespace:${namespace} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

			echo "## Ansible ping device:${device}"
			echo ansible "${device}" -i ./ansible/ansible_hosts -m ping
			ansible "${device}" -i ./ansible/ansible_hosts -m ping

			echo "## rebooting device to clear interface counters, device:${device}"
			echo ansible "${device}" -i ./ansible/ansible_hosts -m reboot --become
			ansible "${device}" -i ./ansible/ansible_hosts -m reboot --become
			echo "ansible reboot return code:$?"
			date --utc +"## After reboot %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

			echo "## Ansible ping device:${device}"
			echo ansible "${device}" -i ./ansible/ansible_hosts -m ping
			ansible "${device}" -i ./ansible/ansible_hosts -m ping

			echo "## configuring qdisc on device:${device}"
			echo ansible "${device}" -i ./ansible/ansible_hosts -m script -a "./cake.bash"
			ansible "${device}" -i ./ansible/ansible_hosts -m script -a "./cake.bash"
			date --utc +"## After qdisc configure %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

			echo ip netns exec network"${namespace}" ping -c 10 -w 1 "${octet_a}.${octet_b}.${octet_c}.${octet_d}" |
				tee "/tmp/output_${timestamp}"/"${device}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${iperf_interval}_t_${run_time}_p_${parallel}_ts_ping_before"
			ip netns exec network"${namespace}" ping -c 30 -w 1 "${octet_a}.${octet_b}.${octet_c}.${octet_d}" |
				tee "/tmp/output_${timestamp}"/"${device}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${iperf_interval}_t_${run_time}_p_${parallel}_ts_ping_before"
			date --utc +"## After before ping %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

			stage="before"
			gather_details_for_tests_from_devices "${device}" "${qdisc}" "${stage}" "${timestamp}"
			gather_details_for_tests_from_laptops "${device}" "${qdisc}" "${stage}" "${timestamp}"

			iperf_start_time=$(date --utc +"%Y_%m_%d_%H:%M:%S")

			echo "### Starting IPERF ###"
			echo "##device:${device} qdisc:${qdisc} namespace:${namespace} vlan:${vlan} ${octet_a}.${octet_b}.${octet_c}.${octet_d}/24"

			echo sudo ip netns exec network"${namespace}" \
				iperf \
				--client "${octet_a}.${octet_b}.${octet_c}.${octet_d}" \
				--interval "${iperf_interval}" \
				--time "${run_time}" \
				--parallel "${parallel}" \
				--dualtest \
				--enhanced \
				--sum-only |
				tee "/tmp/output_${timestamp}"/"${device}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${iperf_interval}_t_${run_time}_p_${parallel}_ts_${iperf_start_time}_iperf"

			sudo ip netns exec network"${namespace}" \
				iperf \
				--client "${octet_a}.${octet_b}.${octet_c}.${octet_d}" \
				--interval "${iperf_interval}" \
				--time "${run_time}" \
				--parallel "${parallel}" \
				--dualtest \
				--enhanced \
				--sum-only |
				tee "/tmp/output_${timestamp}"/"${device}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${iperf_interval}_t_${run_time}_p_${parallel}_ts_${iperf_start_time}_iperf"

			date --utc +"## After iperf %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

			stage="after"
			gather_details_for_tests_from_devices "${device}" "${qdisc}" "${stage}" "${timestamp}"
			gather_details_for_tests_from_laptops "${device}" "${qdisc}" "${stage}" "${timestamp}"

			echo ip netns exec network"${namespace}" ping -c 10 -w 1 "${octet_a}.${octet_b}.${octet_c}.${octet_d}" |
				tee "/tmp/output_${timestamp}"/"${device}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${iperf_interval}_t_${run_time}_p_${parallel}_ts_ping_after"
			ip netns exec network"${namespace}" ping -c 30 -w 1 "${octet_a}.${octet_b}.${octet_c}.${octet_d}" |
				tee "/tmp/output_${timestamp}"/"${device}"/"device_${device}_qdisc_${qdisc}_ns_${namespace}_i_${iperf_interval}_t_${run_time}_p_${parallel}_ts_ping_after"
			date --utc +"## After after ping %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

			qdisc_end_secs=$(date --utc +%s)
			echo "qdisc_end_secs:${qdisc_end_secs}"

			qdisc_secs=$((qdisc_end_secs - qdisc_start_secs))
			qdisc_mins=$((qdisc_secs / 60))
			echo "qdisc_secs:${qdisc_secs}"
			printf "## qdisc_mins:%.3f" "${qdisc_mins}"

			date --utc +"## End qdisc %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

		done

		date --utc +"## End device %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"

		device_end_secs=$(date --utc +%s)
		echo "## device_end_secs:${device_end_secs}"

		device_secs=$((device_end_secs - device_start_secs))
		device_mins=$((device_secs / 60))

		echo "## device_secs:${device_secs}"
		printf "## device_mins:%.3f" "${device_mins}"

	done

done

test_end_secs=$(date --utc +%s)
echo "test_end_secs:${test_end_secs}"
test_secs=$((test_end_secs - test_start_secs))
test_mins=$((test_secs / 60))
echo "test_secs:${test_secs}"
printf "## test_mins:%.3f" "${test_mins}"

date --utc +"## End tests complete %Y_%m_%d_%H:%M:%S secs_since_epoch:%s"
