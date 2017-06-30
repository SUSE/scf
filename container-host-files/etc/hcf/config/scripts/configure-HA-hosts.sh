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
    local svcacct=/var/run/secrets/kubernetes.io/serviceaccount
    curl --silent \
        --cacert "${svcacct}/ca.crt" \
        -H "Authorization: bearer $(cat "${svcacct}/token")" \
        "https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/namespaces/$(cat "${svcacct}/namespace")/${1#/}"
}

find_cluster_ha_hosts() {
    local component_name this_component hosts
    component_name="${1}"
    this_component="$(k8s_api "/pods/${HOSTNAME}" | jq -crM '.metadata.labels."skiff-role-name"')"

    if test "${this_component}" != "${component_name}" ; then
        # Requesting a different component, use DNS name
        echo "[\"${component_name}.${K8S_SERVICE_DOMAIN_SUFFIX}\"]"
    else
        # Requesting all the pods in this component
        local i
        for (( i = 0 ; i < 60 ; i ++ )) ; do
            hosts="$(k8s_api /pods | jq -crM '
                .items |
                map(
                    select(.metadata.labels."skiff-role-name" == "'"${component_name}"'") |
                    .metadata.name |
                    select(.) |
                    . + "'".${component_name}-pod.${K8S_SERVICE_DOMAIN_SUFFIX}"'"
                )
            ' )"
            if test "${hosts}" != '[]' ; then
                break
            fi
            sleep 1
        done
        if test "${hosts}" == '[]' ; then
            echo "No servers found for ${component_name}.${K8S_SERVICE_DOMAIN_SUFFIX} after 60 seconds; should at least have this container" >&2
            exit 1
        fi
        echo "${hosts}"
    fi
}

if test -z "${K8S_SERVICE_DOMAIN_SUFFIX:-}" ; then
    # Only set this if no custom value was provided
    # We need to use the FQDN because that's the value in /etc/hosts; since the
    # pods aren't ready initially, nothing (including this pod) will resolve
    # via the DNS server.  Using the value in /etc/hosts lets us start the
    # bootstrap node.
    export K8S_SERVICE_DOMAIN_SUFFIX="$(awk '/^search/ { print $2 }' /etc/resolv.conf)"
fi
export K8S_CONSUL_CLUSTER_IPS="$(find_cluster_ha_hosts consul)"
export K8S_NATS_CLUSTER_IPS="$(find_cluster_ha_hosts nats)"
export K8S_ETCD_CLUSTER_IPS="$(find_cluster_ha_hosts etcd)"
export K8S_MYSQL_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"

unset k8s_api
unset find_cluster_ha_hosts
