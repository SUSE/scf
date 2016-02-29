#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.
set -e

ROOT=`readlink -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

if [ $# -eq 0 ]
then
    other_images=($(get_role_images))
else
    other_images=($(to_images "$@"))
fi

local_ip="${local_ip:-$(${ROOT}/container-host-files/opt/hcf/bin/get_ip eth1)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

# Start all other roles
for image in "${other_images[@]}"
do
  handle_restart "$image" "$hcf_overlay_gateway" "${ROOT}/bin/dev-settings.env" || true
done

exit 0
