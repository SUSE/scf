#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.

set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

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
consul_address="http://${local_ip}:8501"
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_consul_container="hcf-consul-server"
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

# Start all the specified roles
for image in "${other_images[@]}"
do
  handle_restart "$image" "$hcf_overlay_gateway" || true
done

echo -e "\n\n\nDone, all specified containers have started.\n"

echo -e "\nIt may take some time for everything to come online."
echo -e "You can use \e[1;96mgato status\e[0m to check if everything is up and running.\n"

exit 0
