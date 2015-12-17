#!/bin/bash
set -e

apt-get remove open-vm-tools -y

cd /tmp
git clone https://github.com/rasa/vmware-tools-patches.git
cd vmware-tools-patches
./download-tools.sh
./untar-and-patch.sh
./compile.sh

#
# mkdir -p /tmp/vmfusion;
# mkdir -p /tmp/vmfusion-archive;
# mount -o loop /home/vagrant/linux.iso /tmp/vmfusion;
# tar xzf /tmp/vmfusion/VMwareTools-*.tar.gz -C /tmp/vmfusion-archive;
# /tmp/vmfusion-archive/vmware-tools-distrib/vmware-install.pl -d
# umount /tmp/vmfusion;
# rm -rf  /tmp/vmfusion;
# rm -rf  /tmp/vmfusion-archive;
# rm -f /home/vagrant/*.iso;
