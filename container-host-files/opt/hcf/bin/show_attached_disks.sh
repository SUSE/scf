#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP
set -e

# For use as a TF provisioner - Inspect the disks attached to the host.
# Argument: Prefix for disk device names.

PATTERN="$1"

echo ___ Show attached disk devices
# Disk only, not the partitions.
for i in $(ls -d /dev/${PATTERN}* | grep -v 'd.1')
do
    sudo fdisk -l $i 2>/dev/null | grep Disk | grep -v identifier
done
exit
