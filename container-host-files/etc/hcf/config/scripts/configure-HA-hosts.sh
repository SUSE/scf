#!/bin/bash

# This script sets up the various HA host address lists.  It is sourced during
# the startup script (run.sh), and we should avoid mutating global state as much
# as possible.

find_cluster_ha_hosts() {
    local component_name="${1}"
    if test -z "${HCP_INSTANCE_ID:-}" ; then
        # on Vagrant / AWS ; HA is not supported
        echo "[\"${component_name}-int\"]"
        return 0
    fi
    local hosts=''
    local i=0
    while test "${i}" -lt 100 ; do
        if host -t A "${component_name}-${i}-int.${HCP_INSTANCE_ID}.svc" >&2 ; then
            hosts="${hosts},\"${component_name}-${i}-int.${HCP_INSTANCE_ID}.svc\""
        else
            break
        fi
        i="$(expr "${i}" + 1)"
    done
    # Return the result, with [] around the hostnames, removing the leading comma
    echo "[${hosts#,}]"
}

case "${HCP_COMPONENT_NAME:-}" in
    mysql|mysql-proxy)
        export MYSQL_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"
        ;;
    api|etcd)
	export ETCD_CLUSTER_IPS="$(find_cluster_ha_hosts etcd)"
	;;
esac

# Note: While every role has a metron-agent, and the metron-agent
# needs access to the etcd cluster, this does not mean that all roles
# have to compute the cluster ips. The metron-agent uses ETCD_HOST as
# its target, which the low-level network setup of the system
# round-robins to all the machines in the etcd sub-cluster.

unset find_cluster_ha_hosts
