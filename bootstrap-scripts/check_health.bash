#!/usr/bin/env bash

monit_user="$1"
monit_pass="$2"
monit_port="$3"
shift 3
job_names="$@"

for service_name in ${job_names}; do
  service_health=$(curl -s -u "${monit_user}:${monit_pass}" "http://127.0.0.1:${monit_port}/_status?format=xml" | xmlstarlet sel -t -m "monit/service[name='${service_name}']" -v status)
  if [[ 0 != "${service_health}" ]]; then
    exit 1
  fi
done

exit 0
