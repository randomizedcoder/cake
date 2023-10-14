#!/usr/bin/bash
#
# gather_details_for_tests
#
# This script gathers device specific information into a tmp folder,
# allowing the data to the rsync-ed.  This version graps stats before and after tests

if [[ -n $1 ]]; then
	output_folder=$1
else
	echo "please pass output_folder name"
	exit 1
fi

echo "output_folder:${output_folder}"

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

start_dir=${PWD}
echo "start_dir:${start_dir}"

my_hostname=$(hostname)
echo "my_hostname:${my_hostname}"

commands=(
	"rm -rf ${output_folder}"
	"mkdir ${output_folder}"
	"cd ${output_folder}"
	"cat /proc/interrupts > ${output_folder}proc_interrupts"
	"cat /proc/net/dev  > ${output_folder}proc_net_dev"
	"netstat --statistics --tcp > ${output_folder}netstat_statistics"
	"ethtool ${default_route_interface} > ${output_folder}ethtool_${default_route_interface}"
	"ethtool --phy-statistics ${default_route_interface} > ${output_folder}ethtool_phy_statistics_${default_route_interface}"
	"ethtool --statistics ${default_route_interface} > ${output_folder}ethtool_statistics_${default_route_interface}"
	"ip -statistics link show > ${output_folder}ip_link_show"
	"ip -statistics addr show > ${output_folder}ip_addr_show"
)

for command in "${commands[@]}"; do
	echo "command:sudo sh -c '${command}'"
	eval "${command}"
done

echo chown --recursive das:das "${output_folder}"
chown --recursive das:das "${output_folder}"

echo ls -la "${output_folder}"
ls -la "${output_folder}"

cd "${start_dir}" || true
