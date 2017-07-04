#!/bin/sh
set -e

export PATH=$PATH:/root/go/bin

/generate-certs.sh -e uaa-settings /tmp/uaa-certs.env > /dev/null
/generate-dev-certs.sh -e scf-settings ${namespace} /tmp/scf-certs.env > /dev/null

sed 's/^\([A-Z_]\+\)=\(.\+\)/\1: "\2"/g' < /tmp/uaa-certs.env > /out/uaa-cert-values.yaml
sed 's/^\([A-Z_]\+\)=\(.\+\)/\1: "\2"/g' < /tmp/scf-certs.env > /out/scf-cert-values.yaml

