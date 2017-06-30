#!/bin/sh
set -e

export PATH=$PATH:/root/go/bin

/generate-certs.sh -e uaa-settings /out/uaa-certs.env
/generate-dev-certs.sh -e scf-settings cf /out/scf-certs.env

