#!/usr/bin/env bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

set -e

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

  monit_addr="cf-${role_name}.hcf"
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

register_role -1 "consul"
register_role -1 "nats" "nats" "nats_stream_forwarder"
register_role -1 "etcd" "etcd" "etcd_metrics_server"
register_role -1 "stats" "collector"
register_role -1 "ha_proxy" "haproxy" "consul_template"
register_role -1 "postgres" "postgres"
register_role -1 "uaa" "uaa" "uaa_cf-registrar"
register_role -1 "api" "cloud_controller_migration" "cloud_controller_ng" "cloud_controller_worker_local_1" "cloud_controller_worker_local_2" "nginx_cc" "routing-api" "statsd-injector"
register_role -1 "clock_global" "cloud_controller_clock"
register_role -1 "api_worker" "cloud_controller_worker_1"
register_role -1 "hm9000" "hm9000_analyzer" "hm9000_api_server" "hm9000_evacuator" "hm9000_fetcher" "hm9000_listener" "hm9000_metrics_server" "hm9000_sender" "hm9000_shredder"
register_role -1 "doppler" "doppler" "syslog_drain_binder"
register_role -1 "loggregator_trafficcontroller" "loggregator_trafficcontroller"
register_role -1 "router" "gorouter"

i=0
while [[ $i != $dea_count ]]; do
  register_role "$i" "runner" "dea_next" "dea_logging_agent"
  ((++i))
done
