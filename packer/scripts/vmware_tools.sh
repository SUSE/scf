#!/bin/bash
set -e
apt-get remove open-vm-tools -y
cd /tmp
git clone https://github.com/rasa/vmware-tools-patches.git
cd vmware-tools-patches
git reset --hard 140bbb601950840afe0175c2a2ef38c6a9f1857f
./download-tools.sh
./untar-and-patch.sh
./compile.sh
