#!/bin/bash

set -e

# Usage: configure_docker.sh <DEVICE_MAPPER_VOLUME> <DEVICE_MAPPER_DATA_SIZE> <DEVICE_MAPPER_METADATA_SIZE>

read -d '' usage <<PATCH || true
Usage (needs root):
  configure_docker.sh <DEVICE_MAPPER_VOLUME> <DEVICE_MAPPER_DATA_SIZE> <DEVICE_MAPPER_METADATA_SIZE>

  DEVICE_MAPPER_VOLUME - e.g. /dev/sdb
  DEVICE_MAPPER_DATA_SIZE - size in GB (e.g. 60)
  DEVICE_MAPPER_METADATA_SIZE - size in GB (e.g. 40); Note that DATA+METADATA must both fit on your volume
PATCH

if [ -z ${1} ]; then echo "${usage}"; exit 1; else DEVICE_MAPPER_VOLUME=$1; fi
if [ -z ${2} ]; then echo "${usage}"; exit 1; else DEVICE_MAPPER_DATA_SIZE=$2; fi
if [ -z ${3} ]; then echo "${usage}"; exit 1; else DEVICE_MAPPER_METADATA_SIZE=$3; fi

# Setup devicemapper
service docker stop
pvcreate $DEVICE_MAPPER_VOLUME
vgcreate vg-docker $DEVICE_MAPPER_VOLUME
lvcreate -L ${DEVICE_MAPPER_DATA_SIZE}G -n data vg-docker
lvcreate -L ${DEVICE_MAPPER_METADATA_SIZE}G -n metadata vg-docker

echo DOCKER_OPTS=\"--storage-driver=devicemapper --storage-opt dm.datadev=/dev/vg-docker/data --storage-opt dm.metadatadev=/dev/vg-docker/metadata\" | sudo tee -a /etc/default/docker

service docker start

# Download images
if [ -n "${IMAGE_TO_PULL}" ]; then
    docker pull ${IMAGE_TO_PULL}
fi
