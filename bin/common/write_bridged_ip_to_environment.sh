#!/usr/bin/env bash

while ! ifconfig eth1 | grep -q addr; do
  sleep 3
done
K8S_VM_BRIDGED_IP=$(ifconfig eth1 | grep -oE 'addr:10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sed 's/addr://g')
echo K8S_VM_BRIDGED_IP=$K8S_VM_BRIDGED_IP >> /etc/environment
