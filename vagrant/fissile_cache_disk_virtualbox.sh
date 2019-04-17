#!/usr/bin/env bash

# Format and mount Fissile cache disk on Virtualbox.

set -o errexit -o nounset

FISSILE_CACHE_DEVICE=$1
FISSILE_CACHE_DIR=$2

MPATH=$(multipath -v 1 -l "${FISSILE_CACHE_DEVICE}")
MDEV="/dev/mapper/${MPATH}"

# Create the partition on the device.
parted "${FISSILE_CACHE_DEVICE}" --script -- mklabel gpt
parted -a optimal "${FISSILE_CACHE_DEVICE}" mkpart primary 0% 100%
kpartx -a "${MDEV}"
MDEVPART=$(lsblk "${MDEV}" --raw --paths --output NAME,TYPE | awk 'match($2, "part") { print $1 }')

# Create the filesystem on the device.
mkfs.btrfs "${MDEVPART}"

# Mount the filesystem.
mkdir -p "${FISSILE_CACHE_DIR}"
mount "${MDEVPART}" "${FISSILE_CACHE_DIR}"
chown -R vagrant:vagrant "${FISSILE_CACHE_DIR}"

# Add the filesystem to fstab.
BLOCK_UUID=$(blkid "${MDEVPART}" --match-tag UUID --output value)
BLOCK_TYPE=$(blkid "${MDEVPART}" --match-tag TYPE --output value)
echo "UUID=${BLOCK_UUID} ${FISSILE_CACHE_DIR} ${BLOCK_TYPE} defaults 0 2" >> /etc/fstab
