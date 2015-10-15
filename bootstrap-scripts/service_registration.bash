#!/usr/bin/env bash

set -e

monit_user='monit'
monit_pass='monitpass'
curl -X PUT -d '"nats"' http://127.0.0.1:8501/v1/kv/hcf/user/nats/user
curl -X PUT -d '"goodpass"' http://127.0.0.1:8501/v1/kv/hcf/user/nats/password
curl -X PUT -d '"'${monit_user}'"' http://127.0.0.1:8501/v1/kv/hcf/user/hcf/monit/user
curl -X PUT -d '"'${monit_pass}'"' http://127.0.0.1:8501/v1/kv/hcf/user/hcf/monit/password

function register_service_and_monit {
  service_name="$1"
  monit_port="$2"
  job_names="$@"

  # Register service with health check
  curl -X PUT -d '@-' http://127.0.0.1:8501/v1/agent/service/register <<EOM
  {
    "name": "${service_name}", "tags": ["${service_name}"],
    "check": {
      "id": "${service_name}_check", "interval": "30s",
      "script": "check_health ${monit_user} ${monit_pass} ${monit_port} ${job_names}"
    }
  }
EOM

  # Register monit service with health check
  curl -X PUT -d '@-' http://localhost:8501/v1/agent/service/register <<EOM
  {
    "name": "${service_name}_monit", "tags": ["monit"],
    "port": ${monit_port},
    "check": {
      "id": "${service_name}_monit_check", "interval": "30s",
      "http": "http://${monit_user}:${monit_pass}@127.0.0.1:${monit_port}/_status"
    }
  }
EOM

  # Register monit port
  curl -X PUT -d "${monit_port}" "http://127.0.0.1:8501/v1/kv/hcf/role/${service_name}/hcf/monit/port"
}

register_service_and_monit "consul" "2830" "consul"
register_service_and_monit "nats" "2831" "nats"
register_service_and_monit "etcd" "2832"
register_service_and_monit "stats" "2833"
register_service_and_monit "ha_proxy" "2834"
register_service_and_monit "nfs" "2835"
register_service_and_monit "postgres" "2836"
register_service_and_monit "uaa" "2837"
register_service_and_monit "api" "2838"
register_service_and_monit "clock_global" "2839"
register_service_and_monit "api_worker" "2840"
register_service_and_monit "hm9000" "2841"
register_service_and_monit "doppler" "2842"
register_service_and_monit "loggregator" "2843"
register_service_and_monit "loggregator_trafficcontroller" "2844"
register_service_and_monit "router" "2845"
register_service_and_monit "runner" "2846"
register_service_and_monit "acceptance_tests" "2847"
register_service_and_monit "smoke_tests" "2848"
