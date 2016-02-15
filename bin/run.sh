#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

consul_image=($(get_consul_image))
other_images=($(get_role_images))

local_ip="${local_ip:-$(${ROOT}/container-host-files/opt/hcf/bin/get_ip eth1)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
consul_address="http://${local_ip}:8501"
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_consul_container="hcf-consul-server"
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

# Make sure HCF consul is running
if container_running $hcf_consul_container ; then
  echo "HCF consul server is running ..."
else
  echo "Starting HCF consul ..."
  start_hcf_consul $hcf_consul_container
fi

# Wait for HCF consul to come online
wait_for_consul $consul_address

# Import spec and opinion configurations
run_consullin $consul_address "${FISSILE_WORK_DIR}/hcf-config.tar.gz"

# Import user and role configurations
cluster_info=$(run_configs $consul_address $local_ip)

# Manage the consul role ...
image=$consul_image
if handle_restart $image "$hcf_overlay_gateway" "-p 8500:8500"; then
  echo "CF consul server is running ..."
  # TODO: in this case, everything needs to restart
fi

# Wait for CF consul to start
# TODO: replace with gato status
sleep 10

# Setup health checks
${ROOT}/container-host-files/opt/hcf/bin/service_registration.bash 1

# Start all other roles
for image in "${other_images[@]}"
do
  handle_restart "$image" "$hcf_overlay_gateway" || true
done

echo -e "\n\n\nDone, all containers have started.\n"

# Print cluster information retrieved from configs.sh
echo -e "${cluster_info}"

echo -e "\nIt may take some time for everything to come online."
echo -e "You can use \e[1;96mgato status\e[0m to check if everything is up and running.\n"

exit 0
