#!/bin/bash
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
    image_to_stop=($(to_images "$1"))
fi

local_ip="${local_ip:-$(${ROOT}/container-host-files/opt/hcf/bin/get_ip eth1)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

# Stop the specified role
role_name="$(get_role_name "$image_to_stop")"
echo "Stopping ${role_name} ..."
kill_role "$role_name" || true

exit 0
