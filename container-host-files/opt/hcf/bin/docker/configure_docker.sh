#!/bin/bash

set -e

# Usage: configure_docker.sh <DEVICE_MAPPER_VOLUME> <DEVICE_MAPPER_DATA_SIZE> <DEVICE_MAPPER_METADATA_SIZE> [<IMAGE_TO_PULL>]

usage=<<HELP
configure_docker.sh <DEVICE_MAPPER_VOLUME> <DEVICE_MAPPER_DATA_SIZE> <DEVICE_MAPPER_METADATA_SIZE> [<IMAGE_TO_PULL>]
DEVICE_MAPPER_VOLUME - e.g. /dev/sdb
DEVICE_MAPPER_DATA_SIZE - size in GB (e.g. 60)
DEVICE_MAPPER_METADATA_SIZE - size in GB (e.g. 40); Note that DATA+METADATA must both fit on your volume
IMAGE_TO_PULL - optional; an image to pull so it's cached locally for your convenience
HELP

sudo lsblk

if [ -z ${1} ]; then echo "DEVICE_MAPPER_VOLUME"; exit 1; else DEVICE_MAPPER_VOLUME=$1; fi
if [ -z ${2} ]; then echo "Need to specify a DEVICE_MAPPER_DATA_SIZE"; exit 1; else DEVICE_MAPPER_DATA_SIZE=$2; fi
if [ -z ${3} ]; then echo "Need to specify a DEVICE_MAPPER_METADATA_SIZE"; exit 1; else DEVICE_MAPPER_METADATA_SIZE=$3; fi
if [ -z ${4} ]; then echo "No image specified for download"; else IMAGE_TO_PULL=$4; fi

# Setup devicemapper
sudo service docker stop
sudo pvcreate "$DEVICE_MAPPER_VOLUME"
sudo vgcreate vg-docker "$DEVICE_MAPPER_VOLUME"
sudo lvcreate -L "${DEVICE_MAPPER_VOLUME}G" -n data vg-docker
sudo lvcreate -L "${DEVICE_MAPPER_METADATA_SIZE}G" -n metadata vg-docker

echo DOCKER_OPTS=\"--storage-driver=devicemapper --storage-opt dm.datadev=/dev/vg-docker/data --storage-opt dm.metadatadev=/dev/vg-docker/metadata\" | sudo tee -a /etc/default/docker

sudo service docker start

# Download images
if [ -n "${IMAGE_TO_PULL}" ]; then
    docker pull ${IMAGE_TO_PULL}
fi
