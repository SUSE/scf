#!/bin/bash
set -e

echo "Update Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get dselect-upgrade -y
echo "Install a kernel with quota support"
sudo apt-get update
# Switch was initially made for aufs stability.
# There is currently no hard dependency on this.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-generic-lts-vivid linux-image-extra-virtual-lts-vivid

# Load aufs at boot time
echo "aufs" | sudo tee -a /etc/modules

sudo reboot now
sleep 60
