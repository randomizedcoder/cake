#
# Makefile
#
# This is just a bunch of shortcuts to run commands
#
PWD :=$(shell /usr/bin/pwd)
ANSIBLE_DIR :=${PWD}/ansible/
ANSIBLE_HOSTS :=${ANSIBLE_DIR}ansible_hosts

all: ping copy qdiscs

# ping does an ansible application layer ping, to check ansible is working
ping:
	ANSIBLE_STRATEGY=free ansible devices -i ${ANSIBLE_HOSTS} -m ping
	ANSIBLE_STRATEGY=free ansible laptops -i ${ANSIBLE_HOSTS} -m ping

# copies scripts to the devices to allow us to run them remotely
copy:
	./copy.bash

# runs the script to configure the qdiscs on the remote device
qdiscs: qdiscs_devices qdiscs_laptops

qdiscs_devices:
	ANSIBLE_STRATEGY=free ansible devices -i ${ANSIBLE_HOSTS} -m script -a "./configure_device_scripts/qdisc.bash"

#ansible pi4 -i ${ANSIBLE_HOSTS} -m script -a "./cake.bash"
#ansible jetson-nano -i ${ANSIBLE_HOSTS} -m script -a "./cake.bash"

qdiscs_laptops:
	ANSIBLE_STRATEGY=free ansible laptops -i ${ANSIBLE_HOSTS} -m script -a "./configure_device_scripts/qdisc.bash"

# this starts the iperf and netserver on the ryzen laptop
ryzen_servers:
	ansible ryzen -i ${ANSIBLE_HOSTS} --become -a "/home/das/cake/start_iperf_server_and_netserver_laptop.bash"

run_test:
	ansible 3rd -i ${ANSIBLE_HOSTS} --become -a "/home/das/cake/tests/start_iperf_client_laptop.bash"

copy_test:
	scp ./start_iperf_client_laptop.bash 3rd:/home/das/cake/start_iperf_client_laptop.bash

copy_3rd:
	echo rsync -avzd --exclude '.git' ./ 3rd:/home/das/cake/
	rsync -avzd --exclude '.git' ./ 3rd:/home/das/cake/

# Reference
# https://docs.ansible.com/ansible/latest/reference_appendices/config.html
#