#!/bin/sh

set -o errexit -o nounset

if test -r /etc/secrets/internal-ca-cert ; then
    cp /etc/secrets/internal-ca-cert /usr/local/share/ca-certificates/internalCA.crt
else
    printf "%b" "${INTERNAL_CA_CERT}" > /usr/local/share/ca-certificates/internalCA.crt
fi

update-ca-certificates
