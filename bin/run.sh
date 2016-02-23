#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

set_colors

other_images=($(fissile dev list-roles | grep -v 'smoke-tests\|acceptance-tests\|post_deployment_setup'))

local_ip="${local_ip:-$(${ROOT}/container-host-files/opt/hcf/bin/get_ip eth1)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
config_prefix=$FISSILE_CONFIG_PREFIX
hcf_overlay_gateway=$HCF_OVERLAY_GATEWAY

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
    "loggregator")
      extra="--privileged"
      ;;
    "router")
      extra="--privileged"
      ;;
    "api-worker")
      mkdir -p $store_dir/fake_nfs_share
      touch $store_dir/fake_nfs_share/.nfs_test
      extra="-v $store_dir/fake_nfs_share:/var/vcap/nfs/shared"
      ;;
    "ha-proxy")
      extra="-p 80:80 -p 443:443 -p 4443:4443 -p 2222:2222"
      ;;
    "mysql-proxy")
      extra="-p 3306:3306"
      ;;
    "diego-cell")
      extra="--privileged --cap-add=ALL -v /lib/modules:/lib/modules"
      ;;
    "cf-usb")
      mkdir -p $store_dir/fake_cf_usb_nfs_share
      extra="-v ${store_dir}/fake_cf_usb_nfs_share:/var/vcap/nfs"
      ;;
    "diego-database")
      extra='--add-host="diego-database-0.etcd.service.cf.internal:127.0.0.1"'
      ;;
  esac

  handle_restart \
    "$image" \
    "$hcf_overlay_gateway" \
    "${ROOT}/bin/dev-settings.env" \
    "${ROOT}/bin/dev-certs.env" \
    "$extra" || true
done

. "${ROOT}/bin/dev-settings.env"

echo -e "
Your Helion Cloud Foundry endpoint is: ${bldcyn}https://api.${DOMAIN}${txtrst}
Run the following command to target it: ${bldcyn}cf api --skip-ssl-validation https://api.${DOMAIN}${txtrst}
The Universal Service Broker endpoint is: ${bldcyn}https://usb.${DOMAIN}${txtrst}
Your administrative credentials are:
  Username: ${bldcyn}${CLUSTER_ADMIN_USERNAME}${txtrst}
  Password: ${bldcyn}${CLUSTER_ADMIN_PASSWORD}${txtrst}

It may take some time for everything to come online.
You can use ${bldcyn}hcf-status${txtrst} or ${bldcyn}hcf-status-watch${txtrst} to check if everything is up and running.
"

exit 0
