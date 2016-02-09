#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

consul_image=($(fissile dev list-roles | grep 'consul'))
other_images=($(fissile dev list-roles | grep -v 'consul\|smoke_tests\|acceptance_tests'))

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
  extra=""

  role=$(get_role_name $image)
  case "$role" in
    "api")
      mkdir -p $store_dir/fake_nfs_share
      touch $store_dir/fake_nfs_share/.nfs_test
      extra="-v ${store_dir}/fake_nfs_share:/var/vcap/nfs/shared"
      ;;
    "doppler")
      extra="--privileged"
      ;;
    "loggregator_trafficcontroller")
      extra="--privileged"
      ;;
    "router")
      extra="--privileged"
      ;;
    "api_worker")
      mkdir -p $store_dir/fake_nfs_share
      touch $store_dir/fake_nfs_share/.nfs_test
      extra="-v $store_dir/fake_nfs_share:/var/vcap/nfs/shared"
      ;;
    "ha_proxy")
      extra="-p 80:80 -p 443:443 -p 4443:4443 -p 2222:2222"
      ;;
    "diego_cell")
      extra="--privileged --cap-add=ALL -v /lib/modules:/lib/modules"
      ;;
    "cf-usb")
      mkdir -p $store_dir/fake_cf_usb_nfs_share
      extra="-v ${store_dir}/fake_cf_usb_nfs_share:/var/vcap/nfs"
      ;;
  esac

  handle_restart "$image" "$hcf_overlay_gateway" "$extra" || true
done

echo -e "\n\n\nDone, all containers have started.\n"

# Print cluster information retrieved from configs.sh
echo -e "${cluster_info}"

echo -e "\nIt may take some time for everything to come online."
echo -e "You can use \e[1;96mgato status\e[0m to check if everything is up and running.\n"

exit 0
