#!/bin/bash
set -e

# the default Ubuntu mirror provided in the images is slow slow slow
sudo sed -ik8bak 's/az1\.clouds\.archive\.ubuntu\.com\/ubuntu/mirrors\.rit\.edu\/ubuntu-archive/g' /etc/apt/sources.list
sudo sed -ik8bak 's/security\.ubuntu\.com\/ubuntu/mirrors\.rit\.edu\/ubuntu-archive/g' /etc/apt/sources.list

echo "Update Ubuntu"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get dselect-upgrade -y
echo "Install a kernel with quota support"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-generic-lts-vivid linux-image-extra-virtual-lts-vivid
