#!/bin/sh

# This installs certificate authorities:
# - if available, the internal CA used to identify the components in the cluster
# - if available, the CA used for UAA (from HCP)

set -o errexit -o nounset

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
