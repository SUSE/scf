#!/bin/bash

set -e

varCount=$#

export bulk_api_password=$1 ; shift
export ccdb_role_name=$1 ; shift
export ccdb_role_password=$1 ; shift
export cluster_admin_authorities=$1 ; shift
export cluster_admin_password=$1 ; shift
export cluster_admin_username=$1 ; shift
export cluster_prefix=$1 ; shift
export db_encryption_key=$1 ; shift
export dea_count=$1 ; shift
export domain=$1 ; shift
export doppler_zone=$1 ; shift
export loggregator_shared_secret=$1 ; shift
export metron_agent_zone=$1 ; shift
export monit_password=$1 ; shift
export monit_port=$1 ; shift
export monit_user=$1 ; shift
export nats_password=$1 ; shift
export nats_user=$1 ; shift
export service_provider_key_passphrase=$1 ; shift
export signing_key_passphrase=$1 ; shift
export staging_upload_user=$1 ; shift
export staging_upload_password=$1 ; shift
export traffic_controller_zone=$1 ; shift
export uaa_admin_client_secret=$1 ; shift
export uaa_cc_client_secret=$1 ; shift
export uaa_clients_app_direct_secret=$1 ; shift
export uaa_clients_cc_routing_secret=$1 ; shift
export uaa_clients_developer_console_secret=$1 ; shift
export uaa_clients_doppler_secret=$1 ; shift
export uaa_clients_gorouter_secret=$1 ; shift
export uaa_clients_login_secret=$1 ; shift
export uaa_clients_notifications_secret=$1 ; shift
export uaa_cloud_controller_username_lookup_secret=$1 ; shift
export uaadb_password=$1 ; shift
export uaadb_username=$1 ; shift
end_check=$1
if [[ $end_check != "end_check" ]] ; then
  echo "Expecting an end_check, got $end_check ($varCount vars)"
  exit 1
fi

# Full path needed to gato because we're running this via terraform,
# so the path doesn't include /opt/hcf/bin
OPTDIR=/opt/hcf/bin
which gato 2>/dev/null || export PATH=$PATH:$OPTDIR
gato api http://hcf-consul-server.hcf:8501
. $OPTDIR/configs.sh
