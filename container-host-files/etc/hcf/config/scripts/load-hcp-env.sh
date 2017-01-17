#!/bin/bash

# This script is sourced by the run.sh entrypoint
# It sets up various environment variables needed in HCP

# Note that this is *sourced* into run.sh, so we can't exit the shell.

if test -n "${HCP_INSTANCE_ID:-}" ; then
  # export any UAA clients we need
  export UAA_CLIENTS=`cat /var/vcap/packages/role-manifest/uaa_clients.json`

  # export any UAA authorities we may need
  export UAA_USER_AUTHORITIES=`cat /var/vcap/packages/role-manifest/uaa_authorities.json`
fi
