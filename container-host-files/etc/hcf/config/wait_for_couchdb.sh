#!/bin/bash

function retry () {
    max=${1}
    delay=${2}
    shift 2

    for i in $(seq "${max}")
    do
        "$@" && break || sleep "${delay}"
    done
}

retry 60 10s curl $AUTOSCALER_COUCHDB_HOST:$AUTOSCALER_COUCHDB_PORT 1>/dev/null 2>&1
