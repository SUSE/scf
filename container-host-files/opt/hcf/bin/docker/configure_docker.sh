#!/bin/bash

# Usage: configure_docker.sh <IP_ADDRESS> [<NETWORK_IP>] 
# The network IP is needed to configure DEA containers.

ip_address=$1
case $# in
    1) is_dea_node=0
	cluster_advertise_ip=$1
	neighbor_ip_label=
	daemon_socket_address=$1
	;;
    2) is_dea_node=1
	cluster_advertise_ip=$2
	neighbor_ip_label="--label=com.docker.network.driver.overlay.neighbor_ip=${ip_address}:2376"
	daemon_socket_address=$2
	;;
    *) echo "Expected 1 or 2 args, got $@" ; exit 0
	;;
esac

# Make the code that sets up DOCKER_OPTS more readable.
opts=( --cluster-store=etcd://${ip_address}:3379
       --cluster-advertise=${cluster_advertise_ip}:2376
       --label=com.docker.network.driver.overlay.bind_interface=eth0
       ${neighbor_ip_label}
       -H=${daemon_socket_address}:2376
       -H=unix:///var/run/docker.sock
       -s=devicemapper
       )
case $is_dea_node in
    0) opts[${#opts[@]}]="-g=/data/docker" ;;
esac

echo DOCKER_OPTS=\"${opts[@]}\" | sudo tee -a /etc/default/docker

# enable cgroup memory and swap accounting
sudo sed -idockerbak 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"/' /etc/default/grub
sudo update-grub

case $is_dea_node in
    0) sudo sed -idockerbak 's/local-filesystems and net-device-up IFACE!=lo/local-filesystems and net-device-up IFACE!=lo and started etcd/' /etc/init/docker.conf
    ;;
esac
