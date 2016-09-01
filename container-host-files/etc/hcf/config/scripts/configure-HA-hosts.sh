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
esac

unset find_cluster_ha_hosts
