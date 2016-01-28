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
      "script": "/opt/hcf/bin/check_health.bash ${monit_addr} consul_agent metron_agent ${job_names}"
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

list_all_non_task_roles | while read role
do
  image_name=$(get_image_name "${role}")

  echo "Registering health checks for ${role}"

  # Parse all the monit files inside the containers, so we know what to monitor
  # In the case of process names ending with "<%=", which is the beginning of an
  # erb block, we assume we need an index and we place a 0.
  processes=$(docker run --rm --privileged --entrypoint "bash" $image_name -c \
    "find /var/vcap/jobs-src -name monit -exec cat {} \; | grep ^check\ process | awk '{print \$3}' | sed s/\<\%\=/0/g")

  register_role -1 $role $processes
done
