#!/bin/sh

set -o errexit -o nounset

echo -e ${UAA_CERTIFICATE} > /usr/local/share/ca-certificates/uaa.crt
echo -e ${INTERNAL_CA_CERT} > /usr/local/share/ca-certificates/internalCA.crt
update-ca-certificates
