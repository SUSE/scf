#!/bin/bash

# This script installs the kubernetes packages

set -o errexit -o xtrace

zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check \
    obs://Virtualization:containers Virtualization:containers
# Having a newer kernel seems to mitigate issues with crashing
zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check \
    obs://Kernel:stable/standard Kernel:stable
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive repos --uri # for troubleshooting
zypper --non-interactive install --no-confirm --from Virtualization:containers \
    docker \
    etcd \
    kubernetes-client \
    kubernetes-kubelet \
    kubernetes-master \
    kubernetes-node \
    kubernetes-addons-kubedns \
    kubernetes-node-cni \
    kubernetes-node-image-pause
zypper --non-interactive install --no-confirm --from Kernel:stable \
    kernel-default

systemctl enable etcd.service
systemctl enable kube-apiserver.service
systemctl enable kube-controller-manager.service
systemctl enable kube-proxy.service
systemctl enable kube-scheduler.service
systemctl enable kubelet

# Fake the service account key
ln -s /var/run/kubernetes/apiserver.key /var/lib/kubernetes/serviceaccount.key
mkdir -p /tmp/hostpath_pv
