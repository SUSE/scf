#!/usr/bin/env bash

set -o errexit -o xtrace

# Certstrap is used for creating the k8s signing keys, which are necessary to avoid communication bugs on host restarts
echo "Installing certstrap ..."
# We run chown in docker to avoid requiring sudo
systemctl start docker.service
docker run --rm -v /usr/local/bin:/out:rw "golang:1.11" /usr/bin/env GOBIN=/out go get github.com/square/certstrap
if [[ $(stat -c '%u' "/usr/local/bin/certstrap") -eq 0 ]]; then
  # This pulls the go:1.7 image into the docker image data of the packer-built image. Normally, we'd want to clean this
  # up, but we happen to use this same image in the dev deployment for installing helm-certgen. If the requirement there
  # changes, we should clear the docker image date in the packer building to free up ~200MiB in the image
  docker run --rm -v /usr/local/bin:/out:rw "golang:1.11" /bin/chown "$(id -u):$(id -g)" /out/certstrap
fi
