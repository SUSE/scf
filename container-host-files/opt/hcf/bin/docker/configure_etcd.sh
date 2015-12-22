#!/bin/bash
set -e
echo "Set up etcd to start via upstart"

# Usage: configure_etcd.sh <CLUSTER_PREFIX> <IP_ADDRESS>
cluster_prefix=$1
ip_address=$2

cat >/tmp/etcd.override <<FOE
env ETCD_NAME="${cluster_prefix}-core" 
env ETCD_INITIAL_CLUSTER_TOKEN="${cluster_prefix}-hcf-etcd"
env ETCD_DATA_DIR="/data/hcf-etcd"
env ETCD_LISTEN_PEER_URLS="http://${ip_address}:3380"
env ETCD_LISTEN_CLIENT_URLS="http://${ip_address}:3379"
env ETCD_ADVERTISE_CLIENT_URLS="http://${ip_address}:3379"
env ETCD_INITIAL_CLUSTER="${cluster_prefix}-core=http://${ip_address}:3379"
env ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${ip_address}:3379"
env ETCD_INITIAL_CLUSTER_STATE=new
FOE

sudo mv /tmp/etcd.override /etc/init
sudo mv /tmp/etcd.conf /etc/init

sudo service etcd start
