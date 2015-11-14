#/bin/bash

. .fissilerc

fissile compilation build-base
fissile images create-base
fissile dev compile
fissile dev create-images

consul_image=($(fissile dev list-roles | grep 'consul'))
other_images=($(fissile dev list-roles | grep -v 'consul\|smoke_tests\|acceptance_tests'))

store_dir=~/work-dir/synergy/store/
log_dir=~/work-dir/synergy/log/
consul_address=http://10.0.0.142:8501
config_prefix=hcf

function container_running {
  container_name=$1

  docker inspect ${container_name} > /dev/null 2>&1

  return $?
}

function kill_role {
  role=$1
  docker rm --force $(docker ps -a -q --filter "label=fissile_role=${role}") > /dev/null 2>&1
}

function start_role {
  image=$1
  name=$2
  role=$3

  mkdir -p $store_dir/$role
  mkdir -p $log_dir/$role
  extra=""

  case "$role" in
    "api")
      mkdir -p $store_dir/fake_nfs_share
      touch $store_dir/fake_nfs_share/.nfs_test
      extra="-v $store_dir/fake_nfs_share:/var/vcap/nfs/shared"
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

  docker run -it -d --name $name \
    --privileged \
    --label=fissile_role=$role \
    --dns=127.0.0.1 --dns=8.8.8.8 \
    --cgroup-parent=instance \
    -v $store_dir/$role:/var/vcap/store \
    -v $log_dir/$role:/var/vcap/sys/log \
    -v $FISSILE_COMPILATION_DIR:$FISSILE_COMPILATION_DIR \
    -v $FISSILE_DOCKERFILES_DIR/$role/packages:/var/vcap/packages \
    $extra \
    $image \
    $consul_address \
    $config_prefix > /dev/null 2>&1
}

function get_container_name() {
  echo "${1/:/-}"
}

function get_role_name() {
  role=$(echo $1 | awk -F":" '{print $1}')
  echo ${role#"${FISSILE_REPOSITORY}-"}
}

function handle_restart() {
  image=$1

  container_name=$(get_container_name $image)
  role_name=$(get_role_name $image)

  if container_running $container_name ; then
    echo "Role ${role_name} running with appropriate version ..."
    return 1
  else
    echo "Restarting ${role_name} ..."
    kill_role $role_name
    start_role $image $container_name $role
    return 0
  fi
}

# Manage the consul role ...
image=$consul_image
if handle_restart $image ; then
  sleep 10
  # TODO: in this case, everything needs to restart
fi

# Start all other roles
for image in "${other_images[@]}"
do
  handle_restart $image
done

exit 0