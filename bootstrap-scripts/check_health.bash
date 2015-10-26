#!/usr/bin/env bash

set -e

consul_addr="http://localhost:8501"
monit_user=$(curl -s ${consul_addr}/v1/kv/hcf/user/hcf/monit/user?raw | sed 's/"//g')
monit_pass=$(curl -s ${consul_addr}/v1/kv/hcf/user/hcf/monit/password?raw | sed 's/"//g')
monit_port=$(curl -s ${consul_addr}/v1/kv/hcf/user/hcf/monit/port?raw | sed 's/"//g')
monit_addr="$1"
shift 1
job_names="$@"

is_unhealthy=0

monit_status=$(curl -s -u "${monit_user}:${monit_pass}" "http://${monit_addr}:${monit_port}/_status?format=xml")
if [[ "$?" != 0 ]]; then
  echo "failed to reach monit at: http://${monit_addr}:${monit_port} using provided username and password"
  exit 2
fi

echo -n "$(date '+%Y-%m-%d %H:%M:%S')"
for service_name in ${job_names}; do
  service_health=$(echo "${monit_status}" | xmlstarlet sel -t -m "monit/service[name='${service_name}']" -v status)
  echo -n " ${service_name}=${service_health}"
  if [[ 0 != "${service_health}" ]]; then
    is_unhealthy=2
  fi
done

exit $is_unhealthy
