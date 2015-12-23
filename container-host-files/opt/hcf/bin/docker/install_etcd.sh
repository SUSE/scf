#!/bin/bash
set -e
echo "Install etcd for Docker overlay networking"

curl -L https://github.com/coreos/etcd/releases/download/v2.2.1/etcd-v2.2.1-linux-amd64.tar.gz -o /tmp/etcd.tar.gz
cd /opt
sudo tar xzvf /tmp/etcd.tar.gz
sudo ln -sf /opt/etcd-v2.2.1-linux-amd64 /opt/etcd
