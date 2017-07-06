#!/bin/sh
set -e

export PATH=$PATH:/root/go/bin

env_dir=$(mktemp -dt scf-env.XXXXXXXX)
function finish {
  rm -rf ${env_dir}
  rm -f /tmp/uaa-certs.env /tmp/scf-certs.env
}

trap finish EXIT

cat <<EOF > ${env_dir}/network.env

DOMAIN=${DOMAIN}
HCP_SERVICE_DOMAIN_SUFFIX=${namespace}.svc.cluster.local

EOF

/generate-certs.sh -e ${env_dir} /tmp/uaa-certs.env > /dev/null
/generate-dev-certs.sh -e ${env_dir} "${namespace}" /tmp/scf-certs.env > /dev/null

sed 's/^\([A-Z_]\+\)=\(.\+\)/\1: "\2"/g' < /tmp/uaa-certs.env > /out/uaa-cert-values.yaml
sed 's/^\([A-Z_]\+\)=\(.\+\)/\1: "\2"/g' < /tmp/scf-certs.env > /out/scf-cert-values.yaml

