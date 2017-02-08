#!/bin/bash

# This script sets up the various HA host address lists.  It is sourced during
# the startup script (run.sh), and we should avoid mutating global state as much
# as possible.

# Note: While every role has a metron-agent, and the metron-agent
# needs access to the etcd cluster, this does not mean that all roles
# have to compute the cluster ips. The metron-agent uses ETCD_HOST as
# its target, which the low-level network setup of the system
# round-robins to all the machines in the etcd sub-cluster.


find_cluster_ha_hosts() {
    local component_name="${1}"

    echo "[\"${component_name}-0.${component_name}-pod\"]"
    return 0
}

export CONSUL_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts consul)"
export NATS_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts nats)"
export ETCD_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts etcd)"
export MYSQL_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"

unset find_cluster_ha_hosts

#
# find_cluster_ha_hosts() {
#     local component_name="${1}"
#
#     if test -z "${KUBERNETES_SERVICE_HOST:-}" ; then
#         # on Vagrant / AWS ; HA is not supported
#         # Fall back to simple hostname
#         echo "[\"${component_name}-int\"]"
#         return 0
#     fi
#
#     # We don't have the k8s namespace available, but it _is_ in resolv.conf
#     local domain="$(awk '/^search/ { print $2 }' /etc/resolv.conf)"
#
#     # Loop over the environment to locate the component name variables.
#
#     local hosts=''
#     local name
#     for name in $(dig "${component_name}-pod.${domain}" -t SRV | awk '/IN A/ { print $1 }') ; do
#         hosts="${hosts},\"${name%.}\""
#     done
#     # Return the result, with [] around the hostnames, removing the leading comma
#     echo "[${hosts#,}]"
# }
#
# export CONSUL_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts consul)"
# export NATS_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts nats)"
# export ETCD_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts etcd)"
# export MYSQL_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"
#
# unset find_cluster_ha_hosts
