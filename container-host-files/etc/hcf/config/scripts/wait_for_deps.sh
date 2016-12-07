#!/bin/bash

function process_status() {
  local role="${1}"
  local process="${2}"
  local monit_target="${role}.${HCP_SERVICE_DOMAIN_SUFFIX}:2289"
  local monit_data=$(curl -s http://admin:${MONIT_PASSWORD}@${monit_target}/_status)
  local process_status=$(echo -e "${monit_data}" | grep -A 1 "Process '${process}'" | tail -n1 | awk '{print $2}')
  echo "$process_status"
}

function is_running() {
    local role="${1}"
    local process="${2}"
    local process_status=$(process_status "$1" "$2")
    if [ "$process_status" != "Running" ] 
    then
      return 1
    else 
      return 0
    fi
}

function retry () {
    local max=${1}
    local delay=${2}
    shift 2

    for i in $(seq "${max}")
    do
        eval $@
        test $? -eq 0 && break || sleep "${delay}"
    done
}

if [ "$HCP_COMPONENT_NAME" == "api" ] || [ "$HCP_COMPONENT_NAME" == "api-worker" ] || [ "$HCP_COMPONENT_NAME" == "clock-global" ]
then
  retry 300 5 "is_running mysql-proxy-int switchboard && is_running mysql-int mariadb_ctrl && is_running nats-int nats && is_running blobstore-int blobstore_nginx"
fi


if [ "$HCP_COMPONENT_NAME" == "uaa" ]
then
  retry 300 5 "is_running mysql-proxy-int switchboard && is_running mysql-int mariadb_ctrl"
fi

if [ "$HCP_COMPONENT_NAME" == "sclr-api" ] || [ "$HCP_COMPONENT_NAME" == "sclr-broker" ] || [ "$HCP_COMPONENT_NAME" == "sclr-server" ] 
then
  retry 300 5 "is_running couchdb-int couchdb"
fi


if [ "$HCP_COMPONENT_NAME" == "router" ]
then
  retry 300 5 "is_running uaa-int uaa && is_running nats-int nats && is_running routing-api-int routing-api"
fi

if [ "$HCP_COMPONENT_NAME" == "routing-api" ]
then
  retry 300 5 "is_running uaa-int uaa && is_running nats-int nats"
fi

if [ "$HCP_COMPONENT_NAME" == "routing-ha-proxy" ]
then
  retry 300 5 "is_running uaa-int uaa && is_running nats-int nats"
fi
