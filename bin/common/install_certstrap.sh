#!/usr/bin/env bash

# Certstrap is used for creating the k8s signing keys, which are necessary to avoid communication bugs on host restarts
echo "Installing certstrap ..."
# We run chown in docker to avoid requiring sudo
docker run --rm -v /usr/local/bin:/out:rw "golang:1.7" /usr/bin/env GOBIN=/out go get github.com/square/certstrap
if [[ $(stat -c '%u' "/usr/local/bin/certstrap") -eq 0 ]]; then
  docker run --rm -v /usr/local/bin:/out:rw "golang:1.7" /bin/chown "$(id -u):$(id -g)" /out/certstrap
fi
