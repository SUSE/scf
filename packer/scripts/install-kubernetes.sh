#!/bin/bash

# This script installs the kubernetes packages

set -o errexit -o xtrace

zypper --non-interactive install --no-confirm docker
zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check \
    obs://Virtualization:containers Virtualization:containers
# Having a newer kernel seems to mitigate issues with crashing
zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check \
    obs://Kernel:stable/standard Kernel:stable
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive repos --uri # for troubleshooting
zypper --non-interactive install --no-confirm --from Virtualization:containers \
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

# Fake the service account key
ln -s /var/run/kubernetes/apiserver.key /var/lib/kubernetes/serviceaccount.key



# Turn on host path volume provisioning
perl -p -i -e 's@^(KUBE_CONTROLLER_MANAGER_ARGS=)"(.*)"@\1"\2 --enable-hostpath-provisioner --root-ca-file=/etc/kubernetes/ca/ca.pem"@' /etc/kubernetes/controller-manager

# Tell kubelet to use kubedns for DNS, and give it a cluster domain (we don't care which) to have useful /etc/resolv.conf
perl -p -i -e 's@^(KUBELET_ARGS=)"(.*)"@\1"\2 --cluster-dns=10.254.0.254 --cluster-domain=cluster.local --cgroups-per-qos=false --enforce-node-allocatable='"''"'"@' /etc/kubernetes/kubelet

# Pin kubedns to the IP address we gave to kubelet, and give it more RAM so it doesn't fall over repeatedly
perl -p -i -e '
        s@clusterIP:.*@clusterIP: 10.254.0.254@ ;
        s@170Mi@256Mi@ ;
        s@70Mi@128Mi@ ;
    ' /etc/kubernetes/addons/kubedns.yml

set -o xtrace +o errexit
btrfs subvolume list /var/lib/docker | awk '/docker/ { print "/" $NF }' | xargs --no-run-if-empty btrfs subvolume delete -c
rm -rf /var/lib/docker/* # We'll have a mount point for this afterwards

# Allow the vagrant user use of docker
usermod --append --groups docker vagrant
