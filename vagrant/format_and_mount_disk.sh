#!/usr/bin/env bash

# Format and mount a disk.

set -o errexit -o nounset

DEVICE=$1
MOUNT_DIR=$2

# Create the filesystem on the device.
mkfs.btrfs "${DEVICE}"

# Mount the filesystem.
mkdir -p "${MOUNT_DIR}"
mount "${DEVICE}" "${MOUNT_DIR}"
chown -R vagrant:vagrant "${MOUNT_DIR}"

# Add the filesystem to fstab.
BLOCK_UUID=$(blkid "${DEVICE}" --match-tag UUID --output value)
BLOCK_TYPE=$(blkid "${DEVICE}" --match-tag TYPE --output value)
echo "UUID=${BLOCK_UUID} ${MOUNT_DIR} ${BLOCK_TYPE} defaults 0 2" >> /etc/fstab
