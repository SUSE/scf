#!/usr/bin/env bash

sed -i 's/DOCKER_OPTS="\(.*\)"/DOCKER_OPTS="\1 --storage-driver=overlay2"/' /etc/sysconfig/docker
systemctl restart containerd docker
