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
# start_role <IMAGE_NAME> <CONTAINER_NAME> <ROLE_NAME> <OVERLAY_GATEWAY> <ENV_VARS_FILE> <CERTS_VARS_FILE> <EXTRA_DOCKER_ARGUMENTS>
function start_role {
  image=$1
  name=$2
  role=$3
  overlay_gateway=$4
  env_vars_file=$5
  certs_vars_file=$6
  extra="${@:7}"

  mkdir -p $store_dir/$role
  mkdir -p $log_dir/$role

  docker run -it -d --name $name \
    --net=hcf \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    --label=fissile_role=$role \
    --hostname=${role}.hcf \
    --cgroup-parent=instance \
    --env-file=${env_vars_file} \
    --env-file=${certs_vars_file} \
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
# handle_restart <IMAGE_NAME> <OVERLAY_GATEWAY> <CERTS_VARS_FILE> <ENV_VARS_FILE> <EXTRA_DOCKER_ARGUMENTS>
function handle_restart() {
  image=$1
  overlay_gateway=$2
  env_vars_file=$3
  certs_vars_file=$4
  extra="${@:5}"

  container_name=$(get_container_name $image)
  role_name=$(get_role_name $image)

  if container_running $container_name ; then
    echo "Role ${role_name} running with appropriate version ..."
    return 1
  else
    echo "Restarting ${role_name} ..."
    kill_role $role_name
    start_role $image $container_name $role $overlay_gateway $env_vars_file $certs_vars_file $extra
    return 0
  fi
}

# Loads all roles from the role-manifest.yml
function load_all_roles() {
  role_manifest_file=`readlink -f "${BINDIR}/../../../etc/hcf/config/role-manifest.yml"`

  if [ "${#role_manifest[@]}" == "0" ]; then
    declare -gA 'role_manifest=()'
    declare -gA 'role_manifest_types=()'
    declare -gA 'role_manifest_processes=()'

    # Using this style of while loop so we don't get a subshell
    # because of piping (see http://stackoverflow.com/questions/11942214)
    while IFS= read -r -d '' role_block; do
      role_name=$(echo -n "${role_block}" | awk '/^name: / { print $2 }')
      role_type=$(echo -n "${role_block}" | awk '/^type: / { print $2 }')
      role_processes=$(echo "${role_block}" | shyaml get-value processes '')

      # Default role_type to 'bosh'
      if [ -z "${role_type}" ] ; then
        role_type='bosh'
      fi

      role_manifest["${role_name}"]=$role_block
      role_manifest_types["${role_name}"]=$role_type
      role_manifest_processes["${role_name}"]=$role_processes
    done < <(cat ${role_manifest_file} | shyaml get-values-0 roles)
  fi
}

# Reads all roles that are bosh roles from role-manifest.yml
# Uses shyaml for parsing
# list_all_bosh_roles
function list_all_bosh_roles() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  for role_name in "${!role_manifest_types[@]}"; do
    if [ "${role_manifest_types["$role_name"]}" == "bosh" ] ; then
      echo $role_name
    fi
  done
}

# Reads all roles that are bosh tasks from role-manifest.yml
# Uses shyaml for parsing
# list_all_bosh_task_roles
function list_all_bosh_task_roles() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  for role_name in "${!role_manifest_types[@]}"; do
    if [ "${role_manifest_types["${role_name}"]}" == "bosh-task" ] ; then
      echo $role_name
    fi
  done
}

# Reads all processes for a specific role from the role manifest
# Uses shyaml for parsing
# list_processes_for_role <ROLE_NAME>
function list_processes_for_role() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  role_name_filter=$1

  echo "${role_manifest_processes["${role_name_filter}"]}" | awk '{ print $3 }'
}

# sets the appropiate color values based on $use_colors
function set_colors()
{
  txtred='\e[0;31m' # Red
  txtgrn='\e[0;32m' # Green
  txtylw='\e[0;33m' # Yellow
  txtblu='\e[0;34m' # Blue
  txtpur='\e[0;35m' # Purple
  txtcyn='\e[0;36m' # Cyan
  txtwht='\e[0;37m' # White
  bldblk='\e[1;30m' # Black - Bold
  bldred='\e[1;31m' # Red
  bldgrn='\e[1;32m' # Green
  bldylw='\e[1;33m' # Yellow
  bldblu='\e[1;34m' # Blue
  bldpur='\e[1;35m' # Purple
  bldcyn='\e[1;36m' # Cyan
  bldwht='\e[1;37m' # White
  txtrst='\e[0m'    # Text Reset
}
