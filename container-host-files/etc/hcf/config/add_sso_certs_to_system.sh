#!/bin/sh

set -o errexit -o nounset

echo -e ${UAA_CERTIFICATE} > /usr/local/share/ca-certificates/uaa.crt
echo -e ${SSO_ROUTE_CA_CERT} > /usr/local/share/ca-certificates/sso.crt
update-ca-certificates
