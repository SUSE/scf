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
  extra=$4
  
  mkdir -p $store_dir/$role
  mkdir -p $log_dir/$role

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
  extra=$2
  
  container_name=$(get_container_name $image)
  role_name=$(get_role_name $image)

  if container_running $container_name ; then
    echo "Role ${role_name} running with appropriate version ..."
    return 1
  else
    echo "Restarting ${role_name} ..."
    kill_role $role_name
    start_role $image $container_name $role $extra
    return 0
  fi
}