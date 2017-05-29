#!/bin/bash
set -e

BINDIR=$(readlink -f "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)/")
ROOT=$(readlink -f "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)/../../../../")

# Determines whether a container is running, given a container name and an image name
# container_running <CONTAINER_NAME> <IMAGE_NAME>
function container_running {
  local container_name=$1
  local image_name=$2

  local running=$(docker inspect --format='{{.State.Running}}' ${container_name} 2>/dev/null)
  local running_image=$(docker inspect --format='{{.Config.Image}}' ${container_name} 2>/dev/null)

  if [ "$running" == "false" -o "$running_image" != "$image_name" ] ; then
    return 1
  fi

  return 0
}

# Determines whether a container exists
# container_exists <CONTAINER_NAME>
function container_exists {
  local container_name=$1

  if out=$(docker inspect ${container_name} 2>/dev/null); then
    return 0
  else
    return 1
  fi
}

# Kills an hcf role
# kill_role <ROLE_NAME>
function kill_role {
  local role=$1
  local container=$(docker ps -a -q --filter "label=hcf_role=${role}")
  if [[ ! -z $container ]]; then
    docker rm --force $container > /dev/null 2>&1
  fi
}

# Starts an hcf role
# start_role <IMAGE_NAME> <CONTAINER_NAME> <ROLE_NAME> <ENV_FILE_DIR> <EXTRA>...
function start_role {
  local image=$1
  local name=$2
  local role=$3
  local env_file_dir=$4
  local extra="$(setup_role $role)"
  local hcp_compat_env=""
  local env_files="$(collect_env "$env_file_dir")"
  shift 4
  local user_extra="$@"
  local detach=""
  local restart=""
  local stdin=""

  case "$(get_role_flight_stage ${role})" in
    pre-flight)
      restart="--restart=no"
      stdin="</dev/null"
      hcp_compat_env="--env HCP_JOB_NAME=${role}"
      ;;
    flight)
      detach="--detach"
      restart="--restart=always"
      hcp_compat_env="--env HCP_COMPONENT_NAME=${role}"
      ;;
    post-flight)
      detach="--detach"
      restart="--restart=on-failure"
      stdin="</dev/null"
      hcp_compat_env="--env HCP_JOB_NAME=${role}"
      ;;
  esac

  mkdir -p ${log_dir}/${role}

  # Load all env vars from all files
  env_file_contents=$(cat ${env_files})
  # Load the map that details which vars are allowed for which role
  role_params=$(cat ${ROOT}/vagrant.json | jq -r ".[\"${role}\"]")
  role_params="${role_params}\|HCF_LOG_PROTOCOL"
  role_params="${role_params}\|HCF_LOG_HOST"
  role_params="${role_params}\|HCF_LOG_PORT"

  local edef ename evalue
  local the_env=()
  # Iterate through all env vars that match the ones used by the role
  while read -r edef
  do
      if test "${edef:0:1}" == "#" -o -z "${edef}" ; then
        # Skip comments
        continue
      fi
      ename="${edef%%=*}"
      evalue="${edef#*=}"
      if test "${evalue:0:1}${evalue: -1}" == "''" ; then
        # The variable starts and ends with a single quote; strip it
        evalue="${evalue:1:-1}"
      fi
      # We intentionally only strip single quotes so that if we need to persist
      # quoting through two layers of YAML we can do so using double quotes.
      # Also, this would hopefully reduce the expectation of (shell-style)
      # variable expansion in the *.env files.
      the_env+=("--env=${ename}=${evalue}")
  done < <(echo "${env_file_contents}" | grep -w "${role_params}")

  domain_suffix=$(echo "${env_file_contents}" | awk -F= '/^HCP_SERVICE_DOMAIN_SUFFIX=/ { print $2 }')

  function _do_start_role() {
    docker run --name ${name} \
        ${detach} \
        --net-alias=${role}.${domain_suffix} \
        --net=hcf \
        --dns-search=${domain_suffix} \
        --label=hcf_role=${role} \
        --hostname=${role}.${domain_suffix} \
        --ulimit nofile=200000:200000 \
        ${restart} \
        ${hcp_compat_env} \
        "${the_env[@]}" \
        -v ${log_dir}/${role}:/var/vcap/sys/log \
        ${extra} \
        ${user_extra} \
        ${image}
  }

  eval _do_start_role "${stdin}" "${detach:+>/dev/null}"
  unset _do_start_role
}

# Collect the .env files to use by docker run to initialize the
# container environment. Only files matching *.env are used.
# collect_env <PATH_TO_ENV_FILES>
function collect_env() {
    env_path="$(readlink -f "$1")"
    echo $(ls 2>/dev/null "$env_path"/*.env)
}

# Perform role-specific setup. Return extra arguments needed to start
# the role's container.
# setup_role <ROLE_NAME>
function setup_role() {
  local role="$1"

  # roles/[name]/run
  # - shared-volumes[]/path => fake nfs mounts.
  # - exposed-ports
  # - capabilities

  # Get all possible roles from the role manifest
  load_all_roles

  # Pull the runtime information out of the block
  local role_info="${role_manifest_run["${role}"]}"

  # Add capabilities
  # If there are any capabilities defined, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # --privileged --cap-add="SYS_ADMIN" --cap-add="NET_RAW"
  local capabilities=$(echo "${role_info}" | jq --raw-output --compact-output '.capabilities[] | if length > 0 then "--privileged --cap-add=" + ([.] | join(" --cap-add=")) else "" end')

  # Add exposed ports
  # If there are any exposed ports, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # -p 80:80 -p 443:443
  local ports=""
  local port_info
  while read -r port_info ; do
    local protocol=$(echo "${port_info}" | jq --raw-output .protocol)
    local external_port=$(echo "${port_info}" | jq --raw-output .external)
    local internal_port=$(echo "${port_info}" | jq --raw-output .internal)
    # Forwarding a large range of ports using `-p` is very slow because docker is creating a userland proxy
    # for each port to support hairpin-nat. We used to have a custom iptables implementation for mapping ranges,
    # but not having hairpin-NAT breaks using apps as USB sidecars. It also broke the tcp-routing test when
    # running inside a docker images as part of HAT for unknown reasons.  Find the iptables implementation
    # in the git history if you ever need to test on vagrant with a huge number of tcp routing ports.
    ports="${ports} -p ${external_port}:${internal_port}/${protocol}"
  done < <(echo "${role_info}" | jq --compact-output '."exposed-ports"[] | select(.public)')

  # Add persistent volumes
  # If there are any persistent volume mounts defined, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # -v /store/path/a_tag:/container/path/1 -v /store/path/b_tag:/container/path/2
  local persistent_volumes=$(echo "${role_info}" | jq --raw-output --compact-output '."persistent-volumes"[] | if length > 0 then "-v " + (["'"${store_dir}"'/" + .tag + ":" + .path] | join(" -v ")) else "" end')

  # Add shared volumes
  # If there are any shared volumes defined, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # -v /store/path/a_tag:/container/path/1 -v /store/path/b_tag:/container/path/2
  local shared_volumes=$(echo "${role_info}" | jq --raw-output --compact-output '."shared-volumes"[] | if length > 0 then "-v " + (["'"${store_dir}"'/" + .tag + ":" + .path] | join(" -v ")) else "" end')

  # Add docker volumes
  # If there are any docker volumes defined, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # -v /host/path/1:/container/path/1 -v /host/path/2:/container/path/2
  local docker_volumes=$(echo "${role_info}" | jq --raw-output --compact-output '(."docker-volumes" // []) | map("-v " + .host + ":" + .container) | join(" ")')

  # Alias the container to <component>-0
  local network_alias="--network-alias ${role}-0.hcf.svc"

  # Add arbitrary docker arguments
  local docker_args=$(echo "${role_info}" | jq --raw-output --compact-output '(."docker-args" // []) | join(" ")')

  echo "${capabilities//$'\n'/ } ${ports//$'\n'/ } ${persistent_volumes//$'\n'/ } ${shared_volumes//$'\n'/ } ${docker_volumes//$'\n'/ } ${network_alias//$'\n'/ } ${docker_args}"
}

# gets the role name from a docker image name
# get_container_name <IMAGE_NAME>
function get_container_name() {
  echo $(docker inspect --format '{{.ContainerConfig.Labels.role}}' "$1")
}

# gets an image name from a role name
# IMPORTANT: assumes the image is in the local Docker registry
# IMPORTANT: if more than one image is found, it retrieves the first
# get_image_name <ROLE_NAME>
function get_image_name() {
  local role=$1
  local imageid=$(docker images -q --filter "label=role=${role}" | head -n 1)

  if [ "X$imageid" = X ] ; then
      echo ""
      return
  fi
  docker inspect --format "{{index .RepoTags 0}}" $imageid
}

# checks if the appropriate version of a role is running if it isn't,
# the currently running role is killed, and the correct image is
# started; uses fissile to determine what are the correct images to
# run. The optional extras are user-specified arguments, to enter
# environment-specific settings, see run-role.sh.
#
# handle_restart <ROLE_NAME> <ENV_FILE_DIR> <EXTRA>...
function handle_restart() {
  local role="$1"
  local env_file_dir="$2"
  shift 2
  local extras="$@"
  # The extras are handed down to the 'docker run' command in start_role

  local image=$(get_image_name $role)

  if [ "X$image" = "X" ] ; then
      echo 1>&2 "Unknown role $role, no image found"
      return 1
  fi

  local container_name=$(get_container_name $image)

  if container_running $container_name $image ; then
    echo "Role ${role} running with appropriate version ..."
    return 0
  else
    echo "Restarting ${role} ..."
    kill_role $role
    start_role $image $container_name $role $env_file_dir $extras
    return 0
  fi
}

# Loads all roles from the role-manifest.yml
function load_all_roles() {
  local role_block
  local role_manifest_file=$(readlink -f "${BINDIR}/../../../etc/hcf/config/role-manifest.yml")

  if [ "${#role_manifest[@]}" == "0" ]; then
    declare -g  'role_manifest_data'
    declare -ga 'role_names=()'
    declare -gA 'role_manifest=()'
    declare -gA 'role_manifest_types=()'
    declare -gA 'role_manifest_processes=()'
    declare -gA 'role_manifest_run=()'

    role_manifest_data=$(y2j < ${role_manifest_file})
    # Using this style of while loop so we don't get a subshell
    # because of piping (see http://stackoverflow.com/questions/11942214)
    while IFS= read -r role_block; do
      local role_info=(${role_block})
      local role_name=${role_info[0]}
      local role_type=${role_info[1]}
      local role_processes=${role_info[2]//,/$'\n'}

      role_names+=( "${role_name}" )
      role_manifest["${role_name}"]=$role_block
      role_manifest_types["${role_name}"]=$role_type
      role_manifest_processes["${role_name}"]=$role_processes
    done < <(printf '%s' "${role_manifest_data}" | jq --raw-output '.roles[] | .name + " " + (.type // "bosh") + " " + ([(.processes//[])[].name]//[] | join(","))')

    while IFS= read -r role_block; do
      role_name=$(printf '%s' "${role_block}" | jq --raw-output '.name')
      role_run=$(printf '%s' "${role_block}" | jq --raw-output --compact-output '.run')
      role_manifest_run["${role_name}"]=$role_run
    done < <(printf '%s' "${role_manifest_data}" | jq --raw-output --compact-output '.roles[] | {name:.name, run:.run}')
  fi
}

# Return all roles that are of the given stage
# list_roles_by_flight_stage <FLIGHT_STAGE>
function list_roles_by_flight_stage() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  local stage="$1"
  echo "${role_manifest_data}" | jq --raw-output --compact-output '.roles | map(select((.run."flight-stage" // "flight") == "'${stage}'") | .name) | .[]'
}

# Get the flight stage of the given role
# get_role_flight_stage <ROLE_NAME>
function get_role_flight_stage() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  local role_name="$1"
  echo "${role_manifest_data}" | jq --raw-output --compact-output ' .roles | map(select(.name=="'${role_name}'")) | .[0].run."flight-stage" // "flight" '
}

# Get the type of the given role
# get_role_type <ROLE_NAME>
function get_role_type() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  local role_name="$1"
  echo ${role_manifest_types[${role_name}]}
}

# Return all roles that are of the given type
# list_roles_by_type <ROLE_TYPE>
function list_roles_by_type() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  local type="$1"
  echo "${role_manifest_data}" | jq --raw-output --compact-output '.roles | map(select((.type // "bosh") == "'${type}'") | .name) | .[]'
}

# Reads all roles that are bosh roles from role-manifest.yml
# list_all_bosh_roles
function list_all_bosh_roles() {
  list_roles_by_type bosh
}

# Reads all roles that are docker roles from role-manifest.yml
# list_all_docker_roles
function list_all_docker_roles() {
  list_roles_by_type docker
}

# Reads all roles that are bosh tasks from role-manifest.yml
# list_all_bosh_task_roles
function list_all_bosh_task_roles() {
  list_roles_by_type bosh-task
}

# Reads all processes for a specific role from the role manifest
# list_processes_for_role <ROLE_NAME>
function list_processes_for_role() {
  if [ "${#role_manifest[@]}" == "0" ]; then
    printf "%s" "No role manifest loaded. Forgot to call load_all_roles?" 1>&2
    exit 1
  fi

  local role_name_filter=$1

  echo "${role_manifest_processes["${role_name_filter}"]}"
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
