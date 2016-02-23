#!/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

set -e
CERT_DIR=/home/ubuntu/ca
bindir=$(dirname "$0")
prefix="$1"
HOSTNAME="$2"

mv /tmp/ca $CERT_DIR
cd $CERT_DIR

bash $bindir/generate_root.sh
bash $bindir/generate_intermediate.sh
bash $bindir/generate_host.sh ${prefix}-root "${HOSTNAME}"

