#!/usr/bin/env bash

# Format and mount Fissile cache disk.

set -o errexit -o nounset

FISSILE_CACHE_DEVICE=$1
FISSILE_CACHE_DIR=$2

# Create the filesystem on the device.
mkfs.btrfs "${FISSILE_CACHE_DEVICE}"

# Mount the filesystem.
mkdir -p "${FISSILE_CACHE_DIR}"
mount "${FISSILE_CACHE_DEVICE}" "${FISSILE_CACHE_DIR}"
chown -R vagrant:vagrant "${FISSILE_CACHE_DIR}"

# Add the filesystem to fstab.
BLOCK_UUID=$(blkid "${FISSILE_CACHE_DEVICE}" --match-tag UUID --output value)
BLOCK_TYPE=$(blkid "${FISSILE_CACHE_DEVICE}" --match-tag TYPE --output value)
echo "UUID=${BLOCK_UUID} ${FISSILE_CACHE_DIR} ${BLOCK_TYPE} defaults 0 2" >> /etc/fstab
