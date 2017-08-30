#!/bin/bash

# This script sets up the various HA host address lists.  It is sourced during
# the startup script (run.sh), and we should avoid mutating global state as much
# as possible.

# Note: While every role has a metron-agent, and the metron-agent
# needs access to the etcd cluster, this does not mean that all roles
# have to compute the cluster ips. The metron-agent uses ETCD_HOST as
# its target, which the low-level network setup of the system
# round-robins to all the machines in the etcd sub-cluster.

set -x

k8s_api() {
    local api_ver="$1"
    shift
    local svcacct=/var/run/secrets/kubernetes.io/serviceaccount
    curl --silent \
        --cacert "${svcacct}/ca.crt" \
        -H "Authorization: bearer $(cat "${svcacct}/token")" \
        "https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/${api_ver}/namespaces/$(cat "${svcacct}/namespace")/${1#/}"
}

find_cluster_ha_hosts() {
    local component_name this_component hosts
    component_name="${1}"
    this_component="$(k8s_api api/v1 "/pods/${HOSTNAME}" | jq -crM '.metadata.labels."skiff-role-name"')"

    if test "${this_component}" != "${component_name}" ; then
        # Requesting a different component, use DNS name
        echo "[\"${component_name}.${KUBE_SERVICE_DOMAIN_SUFFIX}\"]"
    elif test "${KUBE_COMPONENT_INDEX}" == "0" ; then
        # This is index 0; don't look for other replicas, this needs to bootstrap
        echo "[${component_name}-0.${component_name}-set.${KUBE_SERVICE_DOMAIN_SUFFIX}]"
    else
        # Find the number of replicas we have
        local statefulset_name replicas i
        statefulset_name="$(k8s_api api/v1 "/pods/${HOSTNAME}" | jq -crM '.metadata.annotations."kubernetes.io/created-by"' | jq -crM .reference.name)"
        replicas=$(k8s_api apis/apps/v1beta1 "/statefulsets/${statefulset_name}" | jq -crM .spec.replicas)

        # Return a list of all replicas
        local hosts=""
        for ((i = 0 ; i < "${replicas}" ; i ++)) ; do
            hosts="${hosts},${component_name}-${i}.${component_name}-set.${KUBE_SERVICE_DOMAIN_SUFFIX}"
        done
        echo "[${hosts#,}]"
    fi
}

if test -z "${KUBE_SERVICE_DOMAIN_SUFFIX:-}" ; then
    # Only set this if no custom value was provided
    # We need to use the FQDN because that's the value in /etc/hosts; since the
    # pods aren't ready initially, nothing (including this pod) will resolve
    # via the DNS server.  Using the value in /etc/hosts lets us start the
    # bootstrap node.
    export KUBE_SERVICE_DOMAIN_SUFFIX="$(awk '/^search/ { print $2 }' /etc/resolv.conf)"
fi
export KUBE_CONSUL_CLUSTER_IPS="$(find_cluster_ha_hosts consul)"
export KUBE_NATS_CLUSTER_IPS="$(find_cluster_ha_hosts nats)"
export KUBE_ETCD_CLUSTER_IPS="$(find_cluster_ha_hosts etcd)"
export KUBE_MYSQL_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"

unset k8s_api
unset find_cluster_ha_hosts
