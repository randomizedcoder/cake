#!/usr/bin/bash

scp cake_3rd.bash 3rd:
scp cake_laptop.bash 3rd:
scp start_netserver_laptop.bash 3rd:
scp start_flent_laptop.bash 3rd:
scp start_iperf_server_laptop.bash 3rd:
scp start_iperf_client_laptop.bash 3rd:

scp cake_ryzen.bash ryzen:
scp start_netserver_laptop.bash ryzen:
scp start_flent_laptop.bash ryzen:
scp start_iperf_server_laptop.bash ryzen:
scp start_iperf_client_laptop.bash ryzen:

scp 3rd:*.flent.gz ./flent/
scp 3rd:*.png ./pngs/

scp ansible_get_facts.yml 3rd:

echo "copying device specific configuration"
scp cake_pi4.bash pi4:
scp cake_pi3b.bash pi3b:
scp cake_jetson.bash jetson:
scp cake_nanopi_neo3.bash nanopi-neo3:
scp cake_nanopi_r5c.bash nanopi-r5c:
scp cake_asus_cn60.bash asus2:

devices=(pi4 pi3b jetson nanopi-neo3 nanopi-r5c asus2)

for device in "${devices[@]}"; do
	echo scp cake_setup_routing_device.bash "${device}":
	scp cake_setup_routing_device.bash "${device}":
done
