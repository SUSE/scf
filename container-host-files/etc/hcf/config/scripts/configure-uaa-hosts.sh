#!/bin/sh

# This file is sourced from roles where the UAA URL is relevant

if test -n "${HCP_INSTANCE_ID:-}" ; then
    # On HCP, we use the UAA they provide
    export HCF_UAA_INTERNAL_HOSTNAME=${HCP_INSTANCE_ID}.${HCP_IDENTITY_EXTERNAL_HOST}
    export HCF_UAA_EXTERNAL_URL="${HCP_IDENTITY_SCHEME:-https}://${HCP_INSTANCE_ID}.${HCP_IDENTITY_EXTERNAL_HOST}:${HCP_IDENTITY_EXTERNAL_PORT}"
    export HCF_UAA_INTERNAL_URL="${HCF_UAA_EXTERNAL_URL}"
elif test -n "${KUBERNETES_NAMESPACE:-}" ; then
    # On raw kubernetes, we deploy UAA separately so it needs a different port
    # (We also pretend it's external) export KUBERNETES_UAA_NAMESPACE="uaa"
    export HCP_IDENTITY_INTERNAL_PORT=2793
    export HCP_IDENTITY_EXTERNAL_PORT=2793
    export HCF_UAA_INTERNAL_HOSTNAME=${KUBERNETES_NAMESPACE}.uaa.${DOMAIN}
    export HCF_UAA_INTERNAL_URL="${HCP_IDENTITY_SCHEME:-https}://${HCF_UAA_INTERNAL_HOSTNAME}:${HCP_IDENTITY_INTERNAL_PORT:-2793}"
    export HCF_UAA_EXTERNAL_URL="${HCF_UAA_INTERNAL_URL}"
else
    # Legacy vagrant
    export HCP_IDENTITY_INTERNAL_PORT=8443
    export HCP_IDENTITY_EXTERNAL_PORT=8443
    export HCF_UAA_INTERNAL_HOSTNAME="hcf.uaa.hcf.svc"
    export HCF_UAA_EXTERNAL_URL="https://hcf.uaa.cf-dev.io:${HCP_IDENTITY_EXTERNAL_PORT}"
    export HCF_UAA_INTERNAL_URL="${HCP_IDENTITY_SCHEME:-https}://${HCF_UAA_INTERNAL_HOSTNAME}:${HCP_IDENTITY_INTERNAL_PORT:-8443}"
fi
