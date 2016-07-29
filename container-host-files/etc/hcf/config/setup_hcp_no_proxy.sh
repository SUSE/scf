#!/usr/bin/env bash

# This file is sourced from run.sh in individual components to configure the
# no_proxy environment variable settings to prevent us from using proxies
# for internal communications

if test -n "${HCF_HCP_CLUSTER_HOSTS:-}" ; then
    export no_proxy="${no_proxy:-${NO_PROXY:-}},${HCF_HCP_CLUSTER_HOSTS}"
    export NO_PROXY="${no_proxy}"
fi
