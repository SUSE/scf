#!/bin/sh
set -e

export PATH=$PATH:/root/go/bin

env_dir=$(mktemp -dt scf-env.XXXXXXXX)
finish() {
  rm -rf "${env_dir}"
  rm -f /tmp/uaa-certs.env /tmp/scf-certs.env
}

trap finish EXIT

cat <<EOF > ${env_dir}/network.env

DOMAIN=${DOMAIN}

EOF

/generate-certs.sh -e "${env_dir}" /tmp/uaa-certs.env > /dev/null
/generate-dev-certs.sh -e "${env_dir}" "${NAMESPACE}" /tmp/scf-certs.env > /dev/null

perl -pe 's@(.+?)=(.+)@$1: "$2"@' < /tmp/uaa-certs.env > /out/uaa-cert-values.yaml
perl -pe 's@(.+?)=(.+)@$1: "$2"@' < /tmp/scf-certs.env > /out/scf-cert-values.yaml

