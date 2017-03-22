#!/bin/bash

# This script pulls the UAA verification key from the live UAA instance, instead
# of the value passed in from the environment.
# It is only applicable to HCP deployments (where we have an external UAA); on
# Vagrant deployments this is unused.

# Note that this is *sourced* into run.sh, so we can't exit the shell.

# Wait for UAA
while true ; do
    if curl --fail \
        $(if test "${SKIP_CERT_VERIFY_EXTERNAL}" = "true" ; then echo "--insecure" ; fi) \
        "${HCF_UAA_INTERNAL_URL}/token_key"
    then
        break
    fi
    sleep 10
done
export JWT_SIGNING_PUB="$(\
    { curl --fail $(if test "${SKIP_CERT_VERIFY_EXTERNAL}" = "true" ; then echo "--insecure" ; fi)\
        "${HCF_UAA_INTERNAL_URL}/token_key" \
        || exit 1 \
    ; } \
    | awk 'BEGIN { RS="," ; FS="\"" } /value/ { if ($2 == "value") print $4 } ')"
