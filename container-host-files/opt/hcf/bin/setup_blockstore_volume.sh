#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP
set -e

# For use as a TF provisioner
# Argument: Device to format and mount

# Process arguments.

DEVICE=$1
DEVICE1=${DEVICE}1

echo Mounting at $DEVICE

# Partition and format device. Single partition (Covering the entire disk?)

sudo parted -s -- $DEVICE unit MB mklabel gpt
sudo parted -s -- $DEVICE unit MB mkpart primary 2048s -0
sudo mkfs.ext4 $DEVICE1

# Remember disk for mounting after reboots, and mount

sudo mkdir -p /data
echo $DEVICE1 /data ext4 defaults,usrquota,grpquota 0 2 | sudo tee -a /etc/fstab
sudo mount /data
exit
