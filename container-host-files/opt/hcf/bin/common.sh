#!/bin/bash
set -e

BINDIR=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/"`

# Determines whether a container is running
# container_running <CONTAINER_NAME>
function container_running {
  container_name=$1

  if out=$(docker inspect --format='{{.State.Running}}' ${container_name} 2>/dev/null); then
    if [ "$out" == "false" ]; then
      return 1
    fi
  else
    return 1
  fi

  return 0
}

# Determines whether a container exists
# container_exists <CONTAINER_NAME>
function container_exists {
  container_name=$1

  if out=$(docker inspect ${container_name} 2>/dev/null); then
    return 0
  else
    return 1
  fi
}

# Kills an hcf role
# kill_role <ROLE_NAME>
function kill_role {
  role=$1
  container=$(docker ps -a -q --filter "label=fissile_role=${role}")
  if [[ ! -z $container ]]; then
    docker rm --force $container > /dev/null 2>&1
  fi
}

# Starts an hcf role
# start_role <IMAGE_NAME> <CONTAINER_NAME> <ROLE_NAME> <OVERLAY_GATEWAY> <ENV_VARS_FILE> <EXTRA_DOCKER_ARGUMENTS>
function start_role {
  image=$1
  name=$2
  role=$3
  overlay_gateway=$4
  env_vars_file=$5
  extra="${@:6}"

  mkdir -p $store_dir/$role
  mkdir -p $log_dir/$role

  docker run -it -d --name $name \
    --net=hcf \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    --label=fissile_role=$role \
    --hostname=${role}.hcf \
    --cgroup-parent=instance \
    --env-file=${env_vars_file} \
    -e "HCF_OVERLAY_GATEWAY=${overlay_gateway}" \
    -e "HCF_NETWORK=overlay" \
    -v $store_dir/$role:/var/vcap/store \
    -v $log_dir/$role:/var/vcap/sys/log \
    $extra \
    $image > /dev/null
}

# Starts the hcf consul server
# start_hcf_consul <CONTAINER_NAME>
function start_hcf_consul() {
  container_name=$1

  mkdir -p $store_dir/$container_name

  if container_exists $container_name ; then
    docker rm $container_name > /dev/null 2>&1
  fi

  cid=$(docker run -d \
    --net=bridge --net=hcf \
    -p 8401:8401 -p 8501:8501 -p 8601:8601 -p 8310:8310 -p 8311:8311 -p 8312:8312 \
    --name $container_name \
    -v $store_dir/$container_name:/opt/hcf/share/consul \
    -t helioncf/hcf-consul-server:latest \
    -bootstrap -client=0.0.0.0 --config-file /opt/hcf/etc/consul.json)
}

# Waits for the hcf consul server to start
# wait_hcf_consul <CONSUL_ADDRESS>
function wait_for_consul() {
  $BINDIR/wait_for_consul.bash $1
}

# gets container name from a fissile docker image name
# get_container_name <IMAGE_NAME>
function get_container_name() {
  echo $(docker inspect --format '{{.ContainerConfig.Labels.role}}' $1)
}

# imports spec and opinion configs into HCF consul
# run_consullin <CONSUL_ADDRESS> <CONFIG_SOURCE>
function run_consullin() {
  $BINDIR/consullin.bash $1 $2
}

# imports default user and role configs
# run_config <CONSUL_ADDRESS> <PUBLIC_IP>
function run_configs() {
  gato api $1
  public_ip=$2 $BINDIR/configs.sh
}

# gets a role name from a fissile image name
# get_role_name <IMAGE_NAME>
function get_role_name() {
  role=$(echo $1 | awk -F":" '{print $1}')
  echo ${role#"${FISSILE_REPOSITORY}-"}
}

# gets an image name from a role name
# IMPORTANT: assumes the image is in the local Docker registry
# IMPORTANT: if more than one image is found, it retrieves the first
# get_image_name <ROLE_NAME>
function get_image_name() {
  role=$1
  echo $(docker inspect --format "{{index .RepoTags 0}}" `docker images -q --filter "label=role=${role}" | head -n 1`)
}

# checks if the appropriate version of a role is running
# if it isn't, the currently running role is killed, and
# the correct image is started;
# uses fissile to determine what are the correct images to run
# handle_restart <IMAGE_NAME> <OVERLAY_GATEWAY> <ENV_VARS_FILE> <EXTRA_DOCKER_ARGUMENTS>
function handle_restart() {
  image=$1
  overlay_gateway=$2
  env_vars_file=$3
  extra="${@:4}"

  container_name=$(get_container_name $image)
  role_name=$(get_role_name $image)

  if container_running $container_name ; then
    echo "Role ${role_name} running with appropriate version ..."
    return 1
  else
    echo "Restarting ${role_name} ..."
    kill_role $role_name
    start_role $image $container_name $role $overlay_gateway $env_vars_file $extra
    return 0
  fi
}

# Reads all roles that are bosh roles from role-manifest.yml
# Uses shyaml for parsing
# list_all_non_task_roles
function list_all_non_task_roles() {
  role_manifest=`readlink -f "${BINDIR}/../../../etc/hcf/config/role-manifest.yml"`

  cat ${role_manifest} | shyaml get-values-0 roles | while IFS= read -r -d '' role_block; do
      role_name=$(echo "${role_block}" | shyaml get-value name)
      role_type=$(echo "${role_block}" | shyaml get-value type bosh)
      if [[ "${role_type}" == "bosh" ]] ; then
        echo $role_name
      fi
  done
}

# Reads all roles that are bosh tasks from role-manifest.yml
# Uses shyaml for parsing
# list_all_task_roles
function list_all_task_roles() {
  role_manifest=`readlink -f "${BINDIR}/../../../etc/hcf/config/role-manifest.yml"`

  cat ${role_manifest} | shyaml get-values-0 roles | while IFS= read -r -d '' role_block; do
    role_name=$(echo "${role_block}" | shyaml get-value name)
    role_type=$(echo "${role_block}" | shyaml get-value type bosh)
    if [[ "${role_type}" == "bosh-task" ]] ; then
      echo $role_name
    fi
  done
}

# Reads all processes for a sepcific role from the role manifest
# Uses shyaml for parsing
# list_all_non_task_roles <ROLE_NAME>
function list_processes_for_role() {
  role_manifest=`readlink -f "${BINDIR}/../../../etc/hcf/config/role-manifest.yml"`
  role_name_filter=$1

  cat ${role_manifest} | shyaml get-values-0 roles | while IFS= read -r -d '' role_block; do
      role_name=$(echo "${role_block}" | shyaml get-value name)

      if [[ "${role_name}" == "${role_name_filter}" ]] ; then
        while IFS= read -r -d '' process_block; do
          process_name=$(echo "${process_block}" | shyaml get-value name)
          echo $process_name
        done < <(echo "${role_block}" | shyaml get-values-0 processes)
      fi
  done
}

# Reads all processes for a sepcific role from the role manifest
# Uses shyaml for parsing
# list_all_non_task_roles <ROLE_NAME>
function list_processes_for_role() {
  role_manifest=`readlink -f ""${BINDIR}/../../../etc/hcf/config/role-manifest.yml""`
  role_name_filter=$1

  cat ${role_manifest} | shyaml get-values-0 roles | while IFS= read -r -d '' role_block; do
      role_name=$(echo "${role_block}" | shyaml get-value name)

      if [[ "${role_name}" == "${role_name_filter}" ]] ; then
        while IFS= read -r -d '' process_block; do
          process_name=$(echo "${process_block}" | shyaml get-value name)
          echo $process_name
        done < <(echo "${role_block}" | shyaml get-values-0 processes)
      fi
  done
}
