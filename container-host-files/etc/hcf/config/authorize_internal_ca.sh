#!/bin/sh

set -o errexit -o nounset

if [ -r /etc/secrets/internal-ca-cert ]; then
  INTERNAL_CA_CERT=`cat /etc/secrets/internal-ca-cert`;
fi

echo -e ${INTERNAL_CA_CERT} > /usr/local/share/ca-certificates/internalCA.crt
update-ca-certificates
