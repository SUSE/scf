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

COUCH_SERVER=couchdb
if test -n "${HCP_SERVICE_DOMAIN_SUFFIX:-}" ; then
    if test -n "${KUBERNETES_NAMESPACE:-}"; then
        HCP_SERVICE_DOMAIN_SUFFIX="${HCP_SERVICE_DOMAIN_SUFFIX/\$\{namespace\}/${KUBERNETES_NAMESPACE}}"
    fi
    COUCH_SERVER="${COUCH_SERVER}.${HCP_SERVICE_DOMAIN_SUFFIX}"
fi

echo "Waiting for couchdb to come online on ${COUCH_SERVER}..."

retry 240 30s curl -s "${COUCH_SERVER}:5984"
