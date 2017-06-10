#!/bin/bash

# This gets the CA cert as an env file

cd "$(dirname "${0}")"

ORIGIN=../../../src/uaa-fissile-release/env/certs.env

awk -F= '($1 == "INTERNAL_CA_CERT" ) { OFS="=" ; $1 = "HCP_CA_CERT" ; print }' ${ORIGIN} > ca.env
