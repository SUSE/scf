#!/bin/bash
set -e

BINDIR=`readlink -f "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)/"`

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
  local env_files="$(collect_env "$env_file_dir")"
  shift 4
  local user_extra="$@"

  mkdir -p $log_dir/$role

  if [[ "$(get_role_flight_stage ${role})" == "flight" ]]; then
    docker run -it --name $name \
        --detach \
        --net=hcf \
        --label=hcf_role=$role \
        --hostname=${role}.hcf \
        $env_files \
        -v $log_dir/$role:/var/vcap/sys/log \
        $extra \
        $user_extra \
        $image > /dev/null
  else
    docker run -it --name $name \
        --net=hcf \
        --label=hcf_role=$role \
        --hostname=${role}.hcf \
        $env_files \
        -v $log_dir/$role:/var/vcap/sys/log \
        $extra \
        $user_extra \
        $image
  fi
}

# Collect the .env files to use by docker run to initialize the
# container environment. Only files matching *.env are used.
# collect_env <PATH_TO_ENV_FILES>
function collect_env() {
    env_path="$(readlink -f "$1")"
    options=""

    for e in $(ls 2>/dev/null "$env_path"/*.env)
    do
	options="$options --env-file=${e}"
    done

    echo $options
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
  local ports=$(echo "${role_info}" | jq --raw-output --compact-output '."exposed-ports"[] | select(.public == true) |  if length > 0 then "-p " + ([(.source | tostring) + ":" + (.target | tostring) + "/" + (.protocol | tostring) ] | join(" -p ")) else "" end')

  # Add persistent volumes
  # If there are any persistent volume mounts defined, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # -v /store/path/a_tag:/container/path/1 -v /store/path/b_tag/container/path/2
  local persistent_volumes=$(echo "${role_info}" | jq --raw-output --compact-output '."persistent-volumes"[] | if length > 0 then "-v " + (["'"${store_dir}"'/" + .tag + ":" + .path] | join(" -v ")) else "" end')

  # Add shared volumes
  # If there are any shared volumes defined, this creates a string that resembles the
  # line below. It returns an empty string otherwise.
  # -v /store/path/a_tag:/container/path/1 -v /store/path/b_tag/container/path/2
  local shared_volumes=$(echo "${role_info}" | jq --raw-output --compact-output '."shared-volumes"[] | if length > 0 then "-v " + (["'"${store_dir}"'/" + .tag + ":" + .path] | join(" -v ")) else "" end')

  # Add anything not found in roles-manifest.yml
  local extra=""
  case "$role" in
    "diego-database")
	  # TODO: Move into role-manifest.yml
	  extra="$extra --add-host='diego-database-0.etcd.service.cf.internal:127.0.0.1'"
	  ;;
  esac

  echo "${capabilities//$'\n'/ } ${ports//$'\n'/ } ${persistent_volumes//$'\n'/ } ${shared_volumes//$'\n'/ } ${extra}"
}

# gets the role name from a docker image name
# get_container_name <IMAGE_NAME>
function get_container_name() {
  echo $(docker inspect --format '{{.ContainerConfig.Labels.role}}' $1)
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
    return 1
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
  local role_manifest_file=`readlink -f "${BINDIR}/../../../etc/hcf/config/role-manifest.yml"`

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
    done < <(echo "${role_manifest_data}" | jq --raw-output '.roles[] | .name + " " + (.type // "bosh") + " " + ([(.processes//[])[].name]//[] | join(","))')

    while IFS= read -r role_block; do
      role_name=$(echo "${role_block}" | jq --raw-output '.name')
      role_run=$(echo "${role_block}" | jq --raw-output --compact-output '.run')
      role_manifest_run["${role_name}"]=$role_run
    done < <(echo "${role_manifest_data}" | jq --raw-output --compact-output '.roles[] | {name:.name, run:.run}')
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
