#!/bin/sh

# This file is sourced from roles where the UAA URL is relevant

if test -n "${HCP_INSTANCE_ID:-}" ; then
    # On HCP, we use the UAA they provide
    export HCF_UAA_INTERNAL_HOSTNAME=${HCP_INSTANCE_ID}.${HCP_IDENTITY_EXTERNAL_HOST}
    export HCF_UAA_EXTERNAL_URL="${HCP_IDENTITY_SCHEME:-https}://${HCP_INSTANCE_ID}.${HCP_IDENTITY_EXTERNAL_HOST}:${HCP_IDENTITY_EXTERNAL_PORT}"
elif test -n "${KUBERNETES_NAMESPACE:-}" ; then
    # On raw kubernetes, we deploy UAA separately so it needs a different port
    export HCP_IDENTITY_INTERNAL_PORT=8443
    export HCP_IDENTITY_EXTERNAL_PORT=8443
    export HCF_UAA_INTERNAL_HOSTNAME=uaa.${KUBERNETES_NAMESPACE}.svc.cluster.local
    export HCF_UAA_EXTERNAL_URL="https://${KUBERNETES_NAMESPACE}.uaa.${DOMAIN}:${HCP_IDENTITY_EXTERNAL_PORT}"
else
    export HCP_IDENTITY_INTERNAL_PORT=8443
    export HCP_IDENTITY_EXTERNAL_PORT=8443
    export HCF_UAA_INTERNAL_HOSTNAME="hcf.uaa-int.hcf.svc"
    export HCF_UAA_EXTERNAL_URL="https://hcf.uaa.cf-dev.io:${HCP_IDENTITY_EXTERNAL_PORT}"
fi
export HCF_UAA_INTERNAL_URL="${HCP_IDENTITY_SCHEME:-https}://${HCF_UAA_INTERNAL_HOSTNAME}:${HCP_IDENTITY_INTERNAL_PORT:-8443}"
