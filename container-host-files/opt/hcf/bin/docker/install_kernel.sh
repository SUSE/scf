#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP
set -e

echo "Update Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get dselect-upgrade -y
echo "Install a kernel with quota support"
sudo apt-get update
# We have no hard dependency on the version, just tracking HCP
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-generic-lts-wily linux-image-extra-virtual-lts-wily

# Load aufs at boot time
echo "aufs" | sudo tee -a /etc/modules

sudo reboot now
sleep 60
