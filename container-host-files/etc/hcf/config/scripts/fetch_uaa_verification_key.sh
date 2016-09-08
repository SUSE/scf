#!/bin/bash

# This script pulls the UAA verification key from the live UAA instance, instead
# of the value passed in from the environment.
# It is only applicable to HCP deployments (where we have an external UAA); on
# Vagrant deployments this is unused.

# Note that this is *sourced* into run.sh, so we can't exit the shell.

if test -n "${HCP_INSTANCE_ID:-}" ; then
    export JWT_SIGNING_PUB="$(\
        curl -v $(if test "${SKIP_CERT_VERIFY_EXTERNAL}" = "true" ; then echo "--insecure" ; fi)\
            "${HCP_IDENTITY_SCHEME}://${HCP_IDENTITY_EXTERNAL_HOST}:${HCP_IDENTITY_EXTERNAL_PORT}/token_key" \
            | awk 'BEGIN { RS="," ; FS="\"" } /value/ { if ($2 == "value") print $4 } ')"
fi
