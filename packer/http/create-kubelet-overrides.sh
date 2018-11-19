#!/usr/bin/env bash

# This file creates kubelet overrides to fix busted packages

mkdir -p /etc/systemd/system/kubelet.service.d/
perl - /etc/kubernetes/kubelet \
    > /etc/systemd/system/kubelet.service.d/vagrant-overrides.env \
    <<"EOF"
use feature "say";
say 'KUBE_ALLOW_PRIV="--allow-privileged"';
while (<>) {
    if (m/^KUBELET_ARGS/) {
        # --cgroups-per-qos is needed for constraints
        # https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/#enabling-qos-and-pod-level-cgroups
        s/--cgroups-per-qos=false//;
        # --network-plugin-dir is now --cni-bin-dir
        s/--network-plugin-dir/--cni-bin-dir/;
        # KubeletConfigFile is always enabled on newer kube
        s/--feature-gates KubeletConfigFile=true//;
        say;
    };
}
EOF
