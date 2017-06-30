#!/bin/sh
set -e

/generate-certs.sh -e uaa-settings /out/uaa-certs.env
/generate-dev-certs.sh -e scf-settings cf /out/scf-certs.env

