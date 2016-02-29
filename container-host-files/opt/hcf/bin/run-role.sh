#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.
set -e

ROOT=`readlink -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

if [ $# -ne 1 ]
then
    echo 1>&2 "Usage: $(basename "$0") role|image"
    exit 1
else
    image_to_run=($(to_images "$1"))
fi

local_ip="${local_ip:-$(${ROOT}/container-host-files/opt/hcf/bin/get_ip eth1)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

# (Re)start the specified role
handle_restart "$image_to_run" \
    "$hcf_overlay_gateway" \
    "${ROOT}/bin/dev-settings.env" \
    "${ROOT}/bin/dev-certs.env" \
    || true

exit 0
