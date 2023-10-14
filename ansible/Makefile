#
# ansible/Makefile
#
PWD :=$(shell /usr/bin/pwd)
ANSIBLE_DIR :=./
ANSIBLE_HOSTS :=${ANSIBLE_DIR}ansible_hosts

all: explain ping show_int_sum show_run_capture show_interface_capture

explain:
	echo "\'make all\' doesn't do much, but it will test the scripts"

# ping does an ansible application layer ping, to check ansible is working
ping:
	ANSIBLE_STRATEGY=free ansible devices -i ${ANSIBLE_HOSTS} -m ping
	ANSIBLE_STRATEGY=free ansible laptops -i ${ANSIBLE_HOSTS} -m ping

#----------------------
# Cisco playbooks

cisco: show_int_sum show_run_capture show_interface_capture

show_int_sum:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_cisco_show_int_sum.yml

clear_counters:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_cisco_clear_counters.yml

clear_counters_interface:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_cisco_clear_counters_interface.yml --extra-vars targets=3750x --extra-vars interface=gi1/0/1

show_run_capture:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_cisco_show_run_capture.yml --extra-vars "file=c3750x_show_run"
	mv ./c3750x_show_run ../device_info/

show_interface_capture:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_cisco_show_interface_capture.yml --extra-vars targets=3750x --extra-vars interface=gi1/0/1 --extra-vars destfile=c3750x_show_int_gi_1_0_1
	#ansible-playbook -i ${ANSIBLE_HOSTS} ansible_cisco_show_interface_capture.yml --extra-vars "interface=$INT destfile=$DESTFILE"

#----------------------
# Linux system playbooks

linux: sudoer install_packages install_packages_laptops upgrade

# installs a file into /etc/sudoers.d/ to allow the 'das' user to sudo without a password
# this means the rest of the playbooks can "become"/sudo without password
sudoer:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --ask-become-pass --extra-vars "targets=devices source_file=${PWD}/sudoers_tweak dest_file=/etc/sudoers.d/das username=root"
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --ask-become-pass --extra-vars "targets=laptops source_file=${PWD}/sudoers_tweak dest_file=/etc/sudoers.d/das username=root"

ansible_config:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --extra-vars "targets=laptops source_file=${PWD}/ansible.cfg dest_file=/home/das/.ansible.cfg username=das"

local_ansible_config:
	cp ./ansible.cfg ~/.ansible.cfg

sshconfig:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --extra-vars "targets=laptops source_file=${PWD}/ssh_config dest_file=/home/das/.ssh/config username=das"

# install packages installs nessiary debian packages for the cake testing
install_packages:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_apt_install_packages.yml

install_packages_laptops:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_apt_install_packages_laptops.yml
	#ansible-playbook -i ${ANSIBLE_HOSTS} ansible_apt_install_packages.yml --ask-become-pass

download_mibs:
	ansible laptops -i ${ANSIBLE_HOSTS} --become -m script -a /usr/bin/download-mibs

snmp_config:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --become --extra-vars "targets=laptops source_file=${PWD}/_etc_snmp_snmp.conf dest_file=/etc/snmp/snmp.conf username=root"

# apt update && apt upgrade --yes
upgrade:
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_apt_update_and_upgrade.yml --extra-vars "host=devices"
	ansible-playbook -i ${ANSIBLE_HOSTS} ansible_apt_update_and_upgrade.yml --extra-vars "host=laptops"
	#ansible-playbook -i ${ANSIBLE_HOSTS} ansible_apt_update_and_upgrade.yml --ask-become-pass