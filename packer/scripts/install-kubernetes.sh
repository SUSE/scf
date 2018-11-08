#!/bin/bash

# This script installs the kubernetes packages

set -o errexit -o xtrace

# Kube doesn't like swap: https://github.com/kubernetes/kubernetes/blob/e4551d50e57c089aab6f67333412d3ca64bc09ae/pkg/kubelet/cm/container_manager_linux.go#L207-L209
swapoff -a

if zypper --no-refresh products --installed-only | grep --silent SLES ; then
    product=SLE
else
    product=openSUSE_Leap
fi
# $releasever is 12.3 on SLE12SP3, but the repo is ...12_SP3; use the string instead
releasever="$(awk -F'"' '/^VERSION=/ { print $2 }' /etc/os-release | tr - _)"

# This repo is needed on SLE for conntrack-tools
if [ "${product}" == "SLE" ] ; then
    zypper --non-interactive addrepo --gpgcheck --refresh --priority 300 --check \
        "http://download.opensuse.org/repositories/Cloud:/OpenStack:/Queens/${product}_${releasever}" \
            OpenStack-Queens
fi

# Use the expanded repo URL to avoid https -> http redirect
zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check \
    "http://download.opensuse.org/repositories/devel:/CaaSP:/Head:/ControllerNode/${product}_${releasever}" \
    CaaSP

zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive repos --uri --priority # for troubleshooting

# SLE 12SP3 have incompatible versions of these
zypper search --installed-only --match-exact \
        containerd \
        docker \
        docker-libnetwork \
        docker-runc \
        runc \
    | awk '/^i/ { print $3 }' \
    | xargs --no-run-if-empty zypper --non-interactive remove --no-confirm

zypper --non-interactive install --no-confirm --from=CaaSP \
    etcd \
    cni-plugins \
    kubernetes-client \
    kubernetes-kubelet \
    kubernetes-master \
    kubernetes-node \
    kubernetes-node-image-pause
# kubernetes-kubelet pulls in docker-kubic automatically

usermod --append --groups docker vagrant || usermod --append --groups docker scf
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
