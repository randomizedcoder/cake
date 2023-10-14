#!/usr/bin/bash
#
# gather_details_local
#
# This script gathers device specific information into a tmp folder,
# allowing the data to the rsync-ed

output_folder=/tmp/device_info/

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
	"cat /proc/cpuinfo > ${output_folder}proc_cpuinfo"
	"cat /proc/meminfo > ${output_folder}proc_meminfo"
	"cat /proc/interrupts > ${output_folder}proc_interrupts"
	"cat /proc/net/dev  > ${output_folder}proc_net_dev"
	"uname -a > ${output_folder}uname_a"
	"cat /etc/os-release > ${output_folder}os_release"
	"cat /etc/lsb-release > ${output_folder}lsb_release"
	"hwloc-ls --output-format png ${output_folder}hwloc-ls-${my_hostname}.png"
	"hwloc-ls > ${output_folder}hwloc-ls"
	"lspci -k > ${output_folder}lspci_k"
	"hwinfo > ${output_folder}hwinfo"
	"hwinfo --network > ${output_folder}hwinfo_network"
	"lshw 2>&1 > ${output_folder}lshw"
	"lshw -class network 2>&1 > ${output_folder}lshw_class_network"
	"sysctl -a 2>&1 > ${output_folder}sysctl_a"
	"netstat --statistics --tcp > ${output_folder}netstat_statistics"
	"ethtool --show-features ${default_route_interface} > ${output_folder}ethtool_show_features_${default_route_interface}"
	"ethtool --phy-statistics ${default_route_interface} > ${output_folder}ethtool_phy_statistics_${default_route_interface}"
	"ethtool --statistics ${default_route_interface} > ${output_folder}ethtool_statistics_${default_route_interface}"
	"ethtool --show-coalesc ${default_route_interface} > ${output_folder}ethtool_show_coalesc_${default_route_interface}"
	"ethtool --show-ring ${default_route_interface} > ${output_folder}ethtool_show_ringm_${default_route_interface}"
	"ethtool --driver ${default_route_interface} > ${output_folder}ethtool_driver_${default_route_interface}"
	"dpkg --list > ${output_folder}dpkg_list"
	"tc -Version > ${output_folder}tc_Version"
	"ip -Version > ${output_folder}ip_Version"
	"ip -statistics link show > ${output_folder}ip_link_show"
	"ip -statistics addr show > ${output_folder}ip_addr_show"
	"ip route show > ${output_folder}ip_route_show"
	"lldpcli show neighbors> ${output_folder}lldpcli_show_neighbors"
)

for command in "${commands[@]}"; do
	echo "command:sudo sh -c '${command}'"
	eval "sudo sh -c '${command}'"
done

cd "${start_dir}" || true
