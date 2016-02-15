#!/bin/bash
# Show log of the specified role.

set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

local_ip="${local_ip:-$(${ROOT}/container-host-files/opt/hcf/bin/get_ip eth1)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
consul_address="http://${local_ip}:8501"
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_consul_container="hcf-consul-server"
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

other_images=($(to_images "$@"))
container=$(image_to_container "${other_images[0]}")

echo Logs of ${other_images[0]}
echo In $container ...
docker logs $container

exit 0
