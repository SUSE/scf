#!/usr/bin/env bash

set -ex
mkdir -p /var/lib/kubelet
mkdir -p /tmp/hostpath_pv
mkdir -p /home/vagrant/.fissile
sed -i 's/DOCKER_OPTS="\(.*\)"/DOCKER_OPTS="\1 --storage-driver=overlay2"/' /etc/sysconfig/docker
systemctl daemon-reload
systemctl enable etcd kube-apiserver kubelet kube-controller-manager kube-proxy kube-scheduler
systemctl restart containerd docker etcd kube-apiserver kubelet kube-controller-manager kube-proxy kube-scheduler
