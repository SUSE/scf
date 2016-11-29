#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP
set -e

# Usage: configure_docker.sh <VOLUME>

read -d '' usage <<PATCH || true
Usage (needs root):
  configure_docker.sh <VOLUME>

  VOLUME - e.g. /dev/sdb
PATCH

# Process arguments

if [ -z "${1}" ]; then echo "${usage}"; exit 1; else VOLUME=$1; fi

# Get global environment (http proxy information, etc)
. /etc/environment

# Setup an overlay ext4 filesystem using logical volume management
# We're using lvm so we can easily resize in the future

service docker stop
pvcreate -ff -y    $VOLUME
pvs

vgcreate vg-docker $VOLUME
vgs

echo ___ LV data
lvcreate -l 100%FREE -n data vg-docker
lvs

mkfs.ext4 -T news /dev/vg-docker/data

echo "/dev/vg-docker/data /var/lib/docker ext4 noatime 0 2" >> /etc/fstab

mount /var/lib/docker

# Insert the device information into the docker configuration
dopts="--storage-driver=overlay2"

# By default, whitelist local network as insecure registry (to work on HCP)
dopts="$dopts --insecure-registry=192.168.0.0/16"

# Limit log file size; don't bother rotating because `docker logs` only uses the current log
dopts="$dopts --log-opt max-file=1 --log-opt max-size=50m"

echo ___ Insert

for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY ; do
  if test -n "${!var}" ; then
    echo "export ${var}=${!var}" | tee -a /etc/default/docker
  fi
done

echo DOCKER_OPTS=\"$dopts\" | tee -a /etc/default/docker

# Activate the now-configured system
service docker start
