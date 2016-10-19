#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP
set -e

echo "Update Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get dselect-upgrade -y
echo "Install a kernel with quota support"
sudo apt-get update
# We have no hard dependency on the version, just tracking HCP
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-generic-lts-xenial linux-image-generic-lts-xenial

# Load aufs at boot time
echo "aufs" | sudo tee -a /etc/modules

# We need to enable memory and swap accounting so that garden-runc works
# properly
sudo sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"/' /etc/default/grub
sudo update-grub

sudo reboot now
sleep 60
