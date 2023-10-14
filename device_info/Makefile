#
# device_info/Makefile
#
PWD :=$(shell /usr/bin/pwd)
ANSIBLE_DIR :=../ansible/
ANSIBLE_HOSTS :=${ANSIBLE_DIR}ansible_hosts

all: explain ping sudoer install_packages upgrade gather_details_locally create_device_dirs rsync

explain:
	echo "\'make all\' sets up sudoers, installs all required binaries, updates code, gathers details, rsyncs the files to the local system"

# ping does an ansible application layer ping, to check ansible is working
ping:
	ANSIBLE_STRATEGY=free ansible devices -i ${ANSIBLE_HOSTS} -m ping
	ANSIBLE_STRATEGY=free ansible laptops -i ${ANSIBLE_HOSTS} -m ping

# ping_ciscos:
# 	ansible ciscos -i ./ansible_hosts -m ping

# installs a file into /etc/sudoers.d/ to allow the 'das' user to sudo without a password
# this means the rest of the playbooks can "become"/sudo without password
sudoer:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --ask-become-pass --extra-vars "targets=devices source_file=${PWD}/sudoers_tweak dest_file=/etc/sudoers.d/das username=root"
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --ask-become-pass --extra-vars "targets=laptops source_file=${PWD}/sudoers_tweak dest_file=/etc/sudoers.d/das username=root"

ansible_config:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_copy.yml --extra-vars "targets=laptops source_file=${PWD}/ansible.cfg dest_file=/home/das/.ansible.cfg username=das"

# install packages installs nessiary debian packages for the cake testing
install_packages:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_apt_install_packages.yml

install_packages_laptops:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_apt_install_packages_laptops.yml
	#ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_apt_install_packages.yml --ask-become-pass

# apt update && apt upgrade --yes
upgrade:
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_apt_update_and_upgrade.yml --extra-vars "host=devices"
	ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_apt_update_and_upgrade.yml --extra-vars "host=laptops"
	#ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_apt_update_and_upgrade.yml --ask-become-pass

#----------------------
# Gather details

# gathers lots of device information into /tmp/device_details/ on each device
gather_details_locally:
	ANSIBLE_STRATEGY=free ansible devices -i ${ANSIBLE_HOSTS} -m script -a "./gather_details_local.bash"
	#ANSIBLE_STRATEGY=linear ansible devices -i ${ANSIBLE_HOSTS} -m script -a "./gather_details_local.bash"

#ansible pi4 -i ./ansible_hosts -m script -a "./gather_details_local.bash"

# creates device_info/{$device} folders
create_device_dirs:
	./create_device_dirs.bash

# which_rsync:
# 	ansible devices -i ./ansible_hosts -m script -a "which rsync"

# rsync-s /tmp/device_details/ from each device to device_info/{$device}
rsync:
	./rsync_device_info.bash

ping_all:
	./ping_devices.bash

# reboot via playbook
reboot_all:
	ANSIBLE_STRATEGY=free ansible-playbook -i ${ANSIBLE_HOSTS} ${ANSIBLE_DIR}ansible_reboot.yml

# reboot via reboot module
# https://docs.ansible.com/ansible/latest/collections/ansible/builtin/reboot_module.html
reboot_all_simple:
	ANSIBLE_STRATEGY=free ansible -m reboot --become -i ${ANSIBLE_HOSTS} devices

# https://docs.ansible.com/ansible/latest/cli/ansible.html
make_cake_folder_on_laptops:
	ansible laptops -i ${ANSIBLE_HOSTS} -m shell -a 'mkdir --parent /home/das/cake/'
#