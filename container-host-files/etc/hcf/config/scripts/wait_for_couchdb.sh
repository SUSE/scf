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

echo "Waiting for couchdb to come online..."

retry 240 30s curl -s couchdb:5984
