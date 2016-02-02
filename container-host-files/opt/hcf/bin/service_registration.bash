#!/usr/bin/env bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

set -e

DIR=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/"`

. "${DIR}/common.sh"

dea_count="$1"
if [[ -z "$dea_count" ]]; then
  echo "Usage: service_registration.bash <dea_count>"
  exit 1
fi

consul_addr="http://localhost:8501"
monit_user=$(curl -s ${consul_addr}/v1/kv/hcf/user/hcf/monit/user?raw | sed 's/"//g')
monit_pass=$(curl -s ${consul_addr}/v1/kv/hcf/user/hcf/monit/password?raw | sed 's/"//g')
monit_port=$(curl -s ${consul_addr}/v1/kv/hcf/user/hcf/monit/port?raw | sed 's/"//g')

function register_role {
  role_index="$1"
  role_name="$2"
  tag_name="$2"

  if [[ -1 != ${role_index} ]]; then
    role_name="${role_name}-${role_index}"
  fi

  image_name=$(get_image_name $role)
  container_name=$(get_container_name $image_name)

  monit_addr="${container_name}.hcf"
  shift 2
  job_names="$@"

  # Register role with health check
  curl -s -X PUT -d '@-' ${consul_addr}/v1/agent/service/register > /dev/null <<EOM
  {
    "name": "${role_name}", "tags": ["${tag_name}"],
    "check": {
      "id": "${role_name}_check", "interval": "30s",
      "script": "/opt/hcf/bin/check_health.bash ${monit_addr} ${job_names}"
    }
  }
EOM

  # Register monit role with health check
  curl -s -X PUT -d '@-' ${consul_addr}/v1/agent/service/register > /dev/null <<EOM
  {
    "name": "${role_name}_monit", "tags": ["monit"],
    "port": ${monit_port},
    "check": {
      "id": "${role_name}_monit_check", "interval": "30s",
      "http": "http://${monit_user}:${monit_pass}@${monit_addr}:${monit_port}/_status"
    }
  }
EOM
}

function deregister_all_roles()
{
  curl -s ${consul_addr}/v1/agent/services | shyaml values-0 | while IFS= read -r -d '' service_block; do
    service_id=$(echo "${service_block}" | shyaml get-value ID)
    if [[ "${service_id}" != "consul" ]] ; then
      # echo "Deregistering service health check '$service_id'"
      curl -s ${consul_addr}/v1/agent/service/deregister/${service_id}
    fi
  done
}

deregister_all_roles

list_all_non_task_roles | while read role
do
  # echo "Registering health checks for ${role}"

  processes=$(list_processes_for_role $role)
  processes=$(echo ${processes})
  # echo -e "  Registered processes: ${processes}"

  register_role -1 $role $processes
done
