#!/bin/sh
set -e

export PATH=$PATH:/root/go/bin

mkdir -p /tmp/scf-env
cat <<EOF > /tmp/scf-env/network.env

DOMAIN=${DOMAIN}
HCP_SERVICE_DOMAIN_SUFFIX=${namespace}.svc.cluster.local

EOF

/generate-certs.sh -e /tmp/scf-env /tmp/uaa-certs.env > /dev/null
/generate-dev-certs.sh -e /tmp/scf-env "${namespace}" /tmp/scf-certs.env > /dev/null

sed 's/^\([A-Z_]\+\)=\(.\+\)/\1: "\2"/g' < /tmp/uaa-certs.env > /out/uaa-cert-values.yaml
sed 's/^\([A-Z_]\+\)=\(.\+\)/\1: "\2"/g' < /tmp/scf-certs.env > /out/scf-cert-values.yaml

