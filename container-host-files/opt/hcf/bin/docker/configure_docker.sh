#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP
set -e

# Usage: configure_docker.sh <DEVICE_MAPPER_VOLUME> <DEVICE_MAPPER_DATA_SIZE> <DEVICE_MAPPER_METADATA_SIZE>

read -d '' usage <<PATCH || true
Usage (needs root):
  configure_docker.sh <DEVICE_MAPPER_VOLUME> <DEVICE_MAPPER_DATA_SIZE> <DEVICE_MAPPER_METADATA_SIZE>

  DEVICE_MAPPER_VOLUME - e.g. /dev/sdb
  DEVICE_MAPPER_DATA_SIZE - size in GB (e.g. 60)
  DEVICE_MAPPER_METADATA_SIZE - size in GB (e.g. 40); Note that DATA+METADATA must both fit on your volume
PATCH

# Process arguments

if [ -z ${1} ]; then echo "${usage}"; exit 1; else DEVICE_MAPPER_VOLUME=$1; fi
if [ -z ${2} ]; then echo "${usage}"; exit 1; else DEVICE_MAPPER_DATA_SIZE=$2; fi
if [ -z ${3} ]; then echo "${usage}"; exit 1; else DEVICE_MAPPER_METADATA_SIZE=$3; fi

# Setup devicemapper via logical volume management

service docker stop
pvcreate -ff -y    $DEVICE_MAPPER_VOLUME
pvs

vgcreate vg-docker $DEVICE_MAPPER_VOLUME
vgs

echo ___ LV data
lvcreate -L ${DEVICE_MAPPER_DATA_SIZE}G     -n data     vg-docker
lvs

echo ___ LV metadata
lvcreate -L ${DEVICE_MAPPER_METADATA_SIZE}G -n metadata vg-docker
lvs

# Insert the device information into the docker configuration

dopts="--storage-driver=devicemapper"
dopts="$dopts --storage-opt dm.datadev=/dev/vg-docker/data"
dopts="$dopts --storage-opt dm.metadatadev=/dev/vg-docker/metadata"
dopts="$dopts --storage-opt dm.basesize=100G"

# By default, whitelist local network as insecure registry (to work on HCP)
dopts="$dopts --insecure-registry=192.168.0.0/16"

for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY ; do
  if test -n "${!var}" ; then
    echo "export ${var}=${!var}" >> /etc/default/docker
  fi
done

echo ___ Insert
echo DOCKER_OPTS=\"$dopts\" | tee -a /etc/default/docker

# Activate the now-configured system

service docker start
