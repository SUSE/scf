#!/bin/bash

# This installs certificate authorities:
# - if available, the internal CA used to identify the components in the cluster
# - if available, the CA used for UAA (from HCP)

# This file is (sometimes) sourced as an environment script, as it is required by
# `fetch_uaa_verification_key.sh`, which itself must be an enviroment script.
# As such, we need to do things to ensure we have an acceptable environment.

os_type=$(get_os_type)
if [ "$os_type" == "ubuntu" ]; then
    ca_path=/usr/local/share/ca-certificates
elif [ "$os_type" == "opensuse" ]; then
    ca_path=/etc/pki/trust/anchors
else
    printf "Error: unknown operating system '${os_type}'"
    exit 1
fi

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
    cp /etc/secrets/internal-ca-cert "${ca_path}"/internalCA.crt
elif [ -n "${INTERNAL_CA_CERT:-}" ]; then
    printf "%b" "${INTERNAL_CA_CERT}" > "${ca_path}"/internalCA.crt
fi

if [ -n "${HCP_CA_CERT_FILE:-}" -a -r "${HCP_CA_CERT_FILE:-}" ]; then
    cp "${HCP_CA_CERT_FILE}" "${ca_path}"/hcp-ca-cert.crt
elif [ -n "${HCP_CA_CERT:-}" ]; then
    printf "%b" "${HCP_CA_CERT}" > "${ca_path}"/hcp-ca-cert.crt
fi

update-ca-certificates
