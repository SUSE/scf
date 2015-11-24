#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/bin/common.sh"

consul_image=($(fissile dev list-roles | grep 'consul'))
other_images=($(fissile dev list-roles | grep -v 'consul\|smoke_tests\|acceptance_tests'))

local_ip="${local_ip:-$(${ROOT}/bootstrap-scripts/get_ip)}"
store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY
consul_address="http://${local_ip}:8501"
config_prefix=$FISSILE_CONFIG_PREFIX

# Manage the consul role ...
image=$consul_image
if handle_restart $image ; then
  sleep 10
  # TODO: in this case, everything needs to restart
fi

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
   "api_worker")
      mkdir -p $store_dir/fake_nfs_share
      touch $store_dir/fake_nfs_share/.nfs_test
      extra="-v $store_dir/fake_nfs_share:/var/vcap/nfs/shared"
      ;;
    "ha_proxy")
      extra="-p 80:80 -p 443:443 -p 4443:4443"
      ;;
    "runner")
      extra="--cap-add=ALL -v /lib/modules:/lib/modules"
      ;;
  esac

  handle_restart "$image" "$extra"
done

exit 0
