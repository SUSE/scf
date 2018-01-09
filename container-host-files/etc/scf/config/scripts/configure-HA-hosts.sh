#!/bin/bash

# This script sets up the various HA host address lists.  It is sourced during
# the startup script (run.sh), and we should avoid mutating global state as much
# as possible.

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

json_get() {
  # Simple JSON getter function
  # The json input is converted to a Python object, so the argument
  # is just Python syntax to access whatever part of the object you
  # need.
  #
  # The JSON data comes in via STDIN

  local filter="$1"

  python -c "import sys, json; print(json.load(sys.stdin)${filter})"
}


find_cluster_ha_hosts() {
    local component_name this_component hosts
    component_name="${1}"
    this_component="$(cat /var/vcap/instance/name)"

    if test "${this_component}" != "${component_name}" ; then
        # Requesting a different component, use DNS name
        echo "[\"${component_name}.${KUBE_SERVICE_DOMAIN_SUFFIX}\"]"
    elif test "${KUBE_COMPONENT_INDEX}" == "0" ; then
        # This is index 0; don't look for other replicas, this needs to bootstrap
        echo "[${component_name}-0.${component_name}-set.${KUBE_SERVICE_DOMAIN_SUFFIX}]"
    else
        # Find the number of replicas we have
        local statefulset_name replicas i
        for ((i = 0 ; i < 5 ; i ++)) ; do
            statefulset_name="$(k8s_api api/v1 "/pods/${HOSTNAME}" | json_get [\'metadata\'][\'annotations\'][\'kubernetes.io/created-by\']  | json_get [\'reference\'][\'name\'])"
            replicas=$(k8s_api apis/apps/v1beta1 "/statefulsets/${statefulset_name}" | json_get [\'spec\'][\'replicas\'])

	    if [ "${statefulset_name}" != "" -a "${replicas}" != "" ]; then
                break
	    fi

            if [ "${statefulset_name}" == "" ]; then
                echo "Cannot get statefulset name from kubernetes API, retrying" >&2
            fi
            if [ "${replicas}" == "" ]; then
                echo "Cannot get replicas from kubernetes API, retrying" >&2
            fi

	    sleep 1
	done
        
        if [ "${statefulset_name}" == "" ]; then
            echo "Cannot get statefulset name from kubernetes API, exit" >&2
            exit 1
        fi
        if [ "${replicas}" == "" ]; then
            echo "Cannot get replicas from kubernetes API, exit" >&2
            exit 1
        fi

        # Return a list of all replicas
        local hosts=""
        for ((i = 0 ; i < "${replicas}" ; i ++)) ; do
            hosts="${hosts},${component_name}-${i}.${component_name}-set.${KUBE_SERVICE_DOMAIN_SUFFIX}"
        done
        echo "[${hosts#,}]"
    fi
}

KUBE_NATS_CLUSTER_IPS="$(find_cluster_ha_hosts nats)"
export KUBE_NATS_CLUSTER_IPS
KUBE_MYSQL_CLUSTER_IPS="$(find_cluster_ha_hosts mysql)"
export KUBE_MYSQL_CLUSTER_IPS

unset json_get
unset k8s_api
unset find_cluster_ha_hosts
