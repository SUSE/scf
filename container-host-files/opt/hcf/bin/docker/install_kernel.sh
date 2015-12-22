#!/bin/bash
set -e

echo "Update Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get dselect-upgrade -y
echo "Install a kernel with quota support"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-generic-lts-vivid linux-image-extra-virtual-lts-vivid

sudo reboot now
sleep 60
