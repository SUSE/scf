#!/bin/bash

# This script installs the kubernetes packages

set -o errexit -o xtrace

# Kube doesn't like swap: https://github.com/kubernetes/kubernetes/blob/e4551d50e57c089aab6f67333412d3ca64bc09ae/pkg/kubelet/cm/container_manager_linux.go#L207-L209
swapoff -a

zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check \
    obs://Virtualization:containers Virtualization:containers
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive repos --uri # for troubleshooting
zypper --non-interactive install --no-confirm --from Virtualization:containers \
    docker \
    etcd-3.2.4 \
    kubernetes-common-1.6.1 \
    kubernetes-client-1.6.1 \
    kubernetes-kubelet-1.6.1 \
    kubernetes-master-1.6.1 \
    kubernetes-node-1.6.1 \
    kubernetes-addons-kubedns-1.5.3 \
    kubernetes-node-cni-1.5.3 \
    kubernetes-node-image-pause-0.1

usermod --append --groups docker vagrant
systemctl enable etcd.service
systemctl enable kube-apiserver.service
systemctl enable kube-controller-manager.service
systemctl enable kube-proxy.service
systemctl enable kube-scheduler.service
systemctl enable kubelet
systemctl enable ntpd

# Fake the service account key
ln -s /var/run/kubernetes/apiserver.key /var/lib/kubernetes/serviceaccount.key
mkdir -p /tmp/hostpath_pv
