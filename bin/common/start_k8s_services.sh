#!/usr/bin/env bash

set -o errexit
mkdir -p /var/lib/kubelet
mkdir -p /tmp/hostpath_pv
mkdir -p /home/vagrant/.fissile
systemctl daemon-reload
systemctl enable etcd kube-apiserver kubelet kube-controller-manager kube-proxy kube-scheduler
systemctl restart etcd kube-apiserver kubelet kube-controller-manager kube-proxy kube-scheduler
