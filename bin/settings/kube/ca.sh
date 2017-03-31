#!/bin/bash

# This gets the CA cert as an env file

cd "$(dirname "${0}")"

awk -F= '($1 == "INTERNAL_CA_CERT" ) { OFS="=" ; $1 = "HCP_CA_CERT" ; print }' ../../../../uaa-fissile-release/env/certs.env > ca.env
