#!/bin/bash

# This installs certificate authorities:
# - if available, the internal CA used to identify the components in the cluster
# - if available, the CA used for UAA (from HCP)

# This file is (sometimes) sourced as an environment script, as it is required by
# `fetch_uaa_verification_key.sh`, which itself must be an enviroment script.
# As such, we need to do things to ensure we have an acceptable environment.

if test -z "${BASH_SOURCE[1]:-}" ; then
    # This is being run standalone
    set -o errexit -o nounset
else
    # This is being sourced from a different script
    if ! ( echo "${SHELLOPTS:-}" | tr ':' '\n' | grep --quiet errexit ) ; then
        printf "Error: errexit not set\n" >&2
        exit 1
    fi
fi

if [ -r /etc/secrets/internal-ca-cert ]; then
    cp /etc/secrets/internal-ca-cert /usr/local/share/ca-certificates/internalCA.crt
elif [ -n "${INTERNAL_CA_CERT:-}" ]; then
    printf "%b" "${INTERNAL_CA_CERT}" > /usr/local/share/ca-certificates/internalCA.crt
fi

if [ -n "${HCP_CA_CERT_FILE:-}" -a -r "${HCP_CA_CERT_FILE:-}" ]; then
    cp "${HCP_CA_CERT_FILE}" /usr/local/share/ca-certificates/hcp-ca-cert.crt
elif [ -n "${HCP_CA_CERT:-}" ]; then
    printf "%b" "${HCP_CA_CERT}" > /usr/local/share/ca-certificates/hcp-ca-cert.crt
fi

update-ca-certificates
