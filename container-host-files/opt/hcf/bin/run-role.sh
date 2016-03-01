#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.
set -e

ROOT=`readlink -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../"`

. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

if [ $# -ne 1 ]
then
    echo 1>&2 "Usage: $(basename "$0") role"
    exit 1
else
    role_name="$1"
fi

# Imported from .runrc .......................
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY
# ............................................

# (Re)start the specified role
handle_restart "$role_name" \
    "$hcf_overlay_gateway" \
    "${ROOT}/bin/dev-settings.env" \
    "${ROOT}/bin/dev-certs.env" \
    || true

exit 0
