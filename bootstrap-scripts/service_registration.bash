#!/usr/bin/env bash

set -e

monit_user='monit'
monit_pass='monitpass'
monit_addr=$(/opt/hcf/bin/get_ip)
curl -X PUT -d '"nats"' http://127.0.0.1:8501/v1/kv/hcf/user/nats/user
curl -X PUT -d '"goodpass"' http://127.0.0.1:8501/v1/kv/hcf/user/nats/password
curl -X PUT -d '"'${monit_user}'"' http://127.0.0.1:8501/v1/kv/hcf/user/hcf/monit/user
curl -X PUT -d '"'${monit_pass}'"' http://127.0.0.1:8501/v1/kv/hcf/user/hcf/monit/password

function register_service_and_monit {
  monit_port="$1"
  service_name="$2"
  shift 2
  job_names="$@"

  # Register service with health check
  curl -X PUT -d '@-' http://127.0.0.1:8501/v1/agent/service/register <<EOM
  {
    "name": "${service_name}", "tags": ["${service_name}"],
    "check": {
      "id": "${service_name}_check", "interval": "30s",
      "script": "/opt/hcf/bin/check_health.bash ${monit_user} ${monit_pass} ${monit_addr} ${monit_port} consul_agent metron_agent ${job_names}"
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
      "http": "http://${monit_user}:${monit_pass}@${monit_addr}:${monit_port}/_status"
    }
  }
EOM

  # Register monit port
  curl -X PUT -d "${monit_port}" "http://127.0.0.1:8501/v1/kv/hcf/role/${service_name}/hcf/monit/port"
}

register_service_and_monit "2830" "consul"
register_service_and_monit "2831" "nats" "nats" "nats_stream_forwarder"
register_service_and_monit "2832" "etcd" "etcd" "etcd_metrics_server"
register_service_and_monit "2833" "stats" "collector"
register_service_and_monit "2834" "ha_proxy" "haproxy" "consul_template"
register_service_and_monit "2835" "postgres" "postgres"
register_service_and_monit "2836" "uaa" "uaa" "uaa_cf-registrar"
register_service_and_monit "2837" "api" "cloud_controller_migration" "cloud_controller_ng" "cloud_controller_worker_local_1" "cloud_controller_worker_local_2" "nginx_cc" "routing-api" "statsd-injector"
register_service_and_monit "2838" "clock_global" "cloud_controller_clock"
register_service_and_monit "2839" "api_worker" "cloud_controller_worker_1"
register_service_and_monit "2840" "hm9000" "hm9000_analyzer" "hm9000_api_server" "hm9000_evacuator" "hm9000_fetcher" "hm9000_listener" "hm9000_metrics_server" "hm9000_sender" "hm9000_shredder"
register_service_and_monit "2841" "doppler" "doppler" "syslog_drain_binder"
register_service_and_monit "2842" "loggregator_trafficcontroller" "loggregator_trafficcontroller"
register_service_and_monit "2843" "router" "gorouter"
register_service_and_monit "2844" "runner" "dea_next" "dea_logging_agent"
# 2855 and 2856 are used for smoke and acceptance tests.
