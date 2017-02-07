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

    # on Vagrant / AWS ; HA is not supported
    # Fall back to simple hostname

    if test -z "${HCP_INSTANCE_ID:-}" ; then
        echo "[\"${component_name}-0.${component_name}-pod\"]"
        return 0
    fi
    #
    # # We are on HCP, loop over the environment to locate the component
    # # name variables.
    #
    # local hosts=''
    # local i=0
    #
    # while test "${i}" -lt 100 ; do
    #     local varname="${component_name^^}_${i}_INT_SERVICE_HOST";
    #     # !varname => Double deref of the variable.
    #     if test -z "${!varname:-}" ; then
    #         break
    #     fi
    #
    #     # Note: The varname deref gives us an IP address. We want the
    #     # actual host name, and construct it.
    #     hosts="${hosts},\"${component_name}-${i}-int.${HCP_SERVICE_DOMAIN_SUFFIX}\""
    #     i="$(expr "${i}" + 1)"
    # done
    # # Return the result, with [] around the hostnames, removing the leading comma
    # echo "[${hosts#,}]"
}

export CONSUL_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts consul)"
export NATS_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts nats)"
export ETCD_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts etcd)"
export MYSQL_HCF_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"

unset find_cluster_ha_hosts
