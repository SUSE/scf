#!/bin/bash
set -e

apt-get remove open-vm-tools -y

cd /tmp
git clone https://github.com/rasa/vmware-tools-patches.git
cd vmware-tools-patches
./download-tools.sh
./untar-and-patch.sh
./compile.sh
