#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

local_ip=`${ROOT}/bootstrap-scripts/get_ip`

# Variables and their defaults
public_ip="${public_ip:-$(echo ${local_ip})}"
bulk_api_password="${bulk_api_password:-password}"
ccdb_role_name="${ccdb_role_name:-ccadmin}"
ccdb_role_password="${ccdb_role_password:-ccpassword}"
ccdb_role_tag="${ccdb_role_tag:-admin}"
certs_prefix="${certs_prefix:-hcf}"
cf_usb_username="${cf_usb_username:-broker-admin}"
cf_usb_password="${cf_usb_password:-changeme}"
cf_usb_uaa_client="${cf_usb_uaa_client:-cf_usb}"
cluster_admin_authorities="${cluster_admin_authorities:-scim.write,scim.read,openid,cloud_controller.admin,doppler.firehose}"
cluster_admin_password="${cluster_admin_password:-changeme}"
cluster_admin_username="${cluster_admin_username:-admin}"
consul_encryption_keys="${consul_encryption_keys:-consul_key}"
db_encryption_key="${db_encryption_key:-the_key}"
domain="${domain:-$(echo ${public_ip}.nip.io)}"
doppler_zone="${doppler_zone:-z1}"
loggregator_shared_secret="${loggregator_shared_secret:-loggregator_endpoint_secret}"
metron_agent_zone="${metron_agent_zone:-z1}"
monit_password="${monit_password:-monit_password}"
monit_port="${monit_port:-2822}"
monit_user="${monit_user:-monit_user}"
nats_password="${nats_password:-nats_password}"
nats_user="${nats_user:-nats_user}"
service_provider_key_passphrase="${service_provider_key_passphrase:-foobar}"
signing_key_passphrase="${signing_key_passphrase:-foobar}"
staging_upload_password="${staging_upload_password:-password}"
staging_upload_user="${staging_upload_user:-username}"
traffic_controller_zone="${traffic_controller_zone:-z1}"
uaa_admin_client_secret="${uaa_admin_client_secret:-admin_secret}"
uaa_batch_password="${uaa_batch_password:-batch_password}"
uaa_batch_username="${uaa_batch_username:-batch_username}"
uaa_cc_client_secret="${uaa_cc_client_secret:-cc_client_secret}"
uaa_clients_app_direct_secret="${uaa_clients_app_direct_secret:-app_direct_secret}"
uaa_clients_developer_console_secret="${uaa_clients_developer_console_secret:-developer_console_secret}"
uaa_clients_doppler_secret="${uaa_clients_doppler_secret:-doppler_secret}"
uaa_clients_gorouter_secret="${uaa_clients_gorouter_secret:-gorouter_secret}"
uaa_clients_login_secret="${uaa_clients_login_secret:-login_client_secret}"
uaa_clients_notifications_secret="${uaa_clients_notifications_secret:-notification_secret}"
uaa_clients_cc_routing_secret="${uaa_clients_cc_routing_secret:-cc_routing_secret}"
uaa_clients_cf_usb_secret="${uaa_clients_cf_usb_secret:-cf_usb_secret}"

uaa_cloud_controller_username_lookup_secret="${uaa_cloud_controller_username_lookup_secret:-cloud_controller_username_lookup_secret}"
uaadb_password="${uaadb_password:-uaaadmin_password}"
uaadb_tag="${uaadb_tag:-admin}"
uaadb_username="${uaadb_username:-uaaadmin}"

# Certificate generation
certs_path="${HOME}/.run/certs"
ca_path="$certs_path/ca"
(
  if [ ! -f $ca_path/intermediate/private/${certs_prefix}-root.chain.pem ] ; then
    # prepare directories
    rm -rf ${certs_path}
    rm -rf ${ca_path}
    mkdir -p ${certs_path}
    mkdir -p ${ca_path}

    cd $ca_path

    cp ${ROOT}/terraform-scripts/hcf/cert/intermediate_openssl.cnf ./
    cp ${ROOT}/terraform-scripts/hcf/cert/root_openssl.cnf ./

    # generate ha_proxy certs
    bash ${ROOT}/terraform-scripts/hcf/cert/generate_root.sh
    bash ${ROOT}/terraform-scripts/hcf/cert/generate_intermediate.sh
    bash ${ROOT}/terraform-scripts/hcf/cert/generate_host.sh "${certs_prefix}-root" "*.${domain}"
    cat intermediate/private/${certs_prefix}-root.key.pem > intermediate/private/${certs_prefix}-root.chain.pem
    cat intermediate/certs/${certs_prefix}-root.cert.pem >> intermediate/private/${certs_prefix}-root.chain.pem
  fi

  if [ ! -f ${certs_path}/jwt_signing.pub ] ; then
    # generate JWT certs
    openssl genrsa -out "${certs_path}/jwt_signing.pem" -passout pass:"${signing_key_passphrase}" 4096
    openssl rsa -in "${certs_path}/jwt_signing.pem" -outform PEM -passin pass:"${signing_key_passphrase}" -pubout -out "${certs_path}/jwt_signing.pub"
  fi
)

# Setting role values
gato config set --role consul                         consul.agent.mode                           'server'
gato config set --role cf-usb                         consul.agent.services.cf_usb                '{}'
gato config set --role uaa                            consul.agent.services.uaa                   '{}'
gato config set --role api                            consul.agent.services.cloud_controller_ng   '{}'
gato config set --role api                            consul.agent.services.routing_api           '{}'
gato config set --role router                         consul.agent.services.gorouter              '{}'
gato config set --role nats                           consul.agent.services.nats                  '{}'
gato config set --role postgres                       consul.agent.services.postgres              '{}'
gato config set --role etcd                           consul.agent.services.etcd                  '{}'
gato config set --role runner                         consul.agent.services.dea_next              '{}'
gato config set --role uaa                            route_registrar.routes                      "[{\"name\": \"uaa\", \"port\":\"8080\", \"tags\":{\"component\":\"uaa\"}, \"uris\":[\"uaa.${domain}\", \"*.uaa.${domain}\", \"login.${domain}\", \"*.login.${domain}\"]}]"
gato config set --role api                            route_registrar.routes                      "[{\"name\":\"api\",\"port\":\"9022\",\"tags\":{\"component\":\"CloudController\"},\"uris\":[\"api.${domain}\"]}]"
gato config set --role hm9000                         route_registrar.routes                      "[{\"name\":\"hm9000\",\"port\":\"5155\",\"tags\":{\"component\":\"HM9K\"},\"uris\":[\"hm9000.${domain}\"]}]"
gato config set --role loggregator_trafficcontroller  route_registrar.routes                      "[{\"name\":\"doppler\",\"port\":\"8081\",\"uris\":[\"doppler.${domain}\"]},{\"name\":\"loggregator_trafficcontroller\",\"port\":\"8080\",\"uris\":[\"loggregator.${domain}\"]}]"
gato config set --role doppler                        route_registrar.routes                      "[{\"name\":\"doppler\",\"port\":\"8081\",\"uris\":[\"doppler.${domain}\"]},{\"name\":\"loggregator_trafficcontroller\",\"port\":\"8080\",\"uris\":[\"loggregator.${domain}\"]}]"
gato config set --role cf-usb                        route_registrar.routes                      "[{\"name\":\"usb\",\"port\":\"54053\",\"uris\":[\"usb.${domain}\", \"*.usb.${domain}\"]}, {\"name\":\"broker\",\"port\":\"54054\",\"uris\":[\"brokers.${domain}\", \"*.brokers.${domain}\"]}]"

# Constants
gato config set consul.agent.servers.lan                '["cf-consul.hcf"]'
gato config set nats.machines                           '["nats.service.cf.internal"]'
gato config set etcd_metrics_server.nats.machines       '["nats.service.cf.internal"]'
gato config set etcd_metrics_server.machines            '["nats.service.cf.internal"]'
gato config set nfs_server.share_path                   '/var/vcap/nfs'
gato config set databases.databases                     '[{"citext":true, "name":"ccdb", "tag":"cc"}, {"citext":true, "name":"uaadb", "tag":"uaa"}]'
gato config set databases.port                          '5524'
gato config set etcd.machines                           '["etcd.service.cf.internal"]'
gato config set loggregator.etcd.machines               '["etcd.service.cf.internal"]'
gato config set router.servers.z1                       '["gorouter.service.cf.internal"]'
gato config set dea_next.kernel_network_tuning_enabled  'false'
gato config set ccdb.address                            'postgres.service.cf.internal'
gato config set databases.address                       'postgres.service.cf.internal'
gato config set uaadb.address                           'postgres.service.cf.internal'

# TODO: Take this out, and place our generated CA cert
# into the appropriate /usr/share/ca-certificates folders
# and call update-ca-certificates at container startup
gato config set ssl.skip_cert_verify        'true'
gato config set disk_quota_enabled          'false'
gato config set metron_agent.deployment     "hcf-deployment"
gato config set consul.require_ssl          "false"
gato config set consul.encrypt_keys         "[]"
gato config set etcd.peer_require_ssl       'false'
gato config set etcd.require_ssl            'false'
gato config set cf-usb.skip_tsl_validation  'true'


# Setting user values
gato config set app_domains                                           "[\"${domain}\"]"
gato config set cc.bulk_api_password                                  "${bulk_api_password}"
gato config set cc.db_encryption_key                                  "${db_encryption_key}"
gato config set cc.srv_api_uri                                        "https://api.${domain}"
gato config set cc.staging_upload_user                                "${staging_upload_user}"
gato config set cc.staging_upload_password                            "${staging_upload_password}"
gato config set ccdb.roles                                            "[{\"name\": \"${ccdb_role_name}\", \"password\": \"${ccdb_role_password}\", \"tag\": \"${ccdb_role_tag}\"}]"
gato config set databases.roles                                       "[{\"name\": \"${ccdb_role_name}\", \"password\": \"${ccdb_role_password}\",\"tag\": \"${ccdb_role_tag}\"}, {\"name\": \"${uaadb_username}\", \"password\": \"${uaadb_password}\", \"tag\":\"${uaadb_tag}\"}]"
gato config set domain                                                "${domain}"
gato config set doppler.zone                                          "${doppler_zone}"
gato config set doppler_endpoint.shared_secret                        "${loggregator_shared_secret}"
gato config set etcd_metrics_server.nats.username                     "${nats_user}"
gato config set etcd_metrics_server.password                          "${nats_password}"
gato config set hcf.monit.user                                        "${monit_user}"
gato config set hcf.monit.password                                    "${monit_password}"
gato config set hcf.monit.port                                        "${monit_port}"
gato config set loggregator_endpoint.shared_secret                    "${loggregator_shared_secret}"
gato config set metron_agent.zone                                     "${metron_agent_zone}"
gato config set nats.user                                             "${nats_user}"
gato config set nats.password                                         "${nats_password}"
gato config set uaa.admin.client_secret                               "${uaa_admin_client_secret}"
gato config set uaa.batch.username                                    "${uaa_batch_username}"
gato config set uaa.batch.password                                    "${uaa_batch_password}"
gato config set uaa.cc.client_secret                                  "${uaa_cc_client_secret}"
gato config set uaa.clients.app-direct.secret                         "${uaa_clients_app_direct_secret}"
gato config set uaa.clients.developer-console.secret                  "${uaa_clients_developer_console_secret}"
gato config set uaa.clients.notifications.secret                      "${uaa_clients_notifications_secret}"
gato config set uaa.clients.login.secret                              "${uaa_clients_login_secret}"
gato config set uaa.clients.cc_routing.secret                         "${uaa_clients_cc_routing_secret}"
gato config set uaa.clients.doppler.secret                            "${uaa_clients_doppler_secret}"
gato config set uaa.clients.cloud_controller_username_lookup.secret   "${uaa_cloud_controller_username_lookup_secret}"
gato config set uaa.clients.gorouter.secret                           "${uaa_clients_gorouter_secret}"
gato config set uaa.scim.users                                        "[\"${cluster_admin_username}|${cluster_admin_password}|${cluster_admin_authorities}\"]"
gato config set uaadb.roles                                           "[{\"name\": \"${uaadb_username}\", \"password\": \"${uaadb_password}\", \"tag\": \"${uaadb_tag}\"}]"
gato config set system_domain                                         "${domain}"
gato config set traffic_controller.zone                               "${traffic_controller_zone}"
# TODO: This should be handled in the 'opinions' file, since the ERB templates will generate this value
gato config set hm9000.url                                            "https://hm9000.${domain}"
gato config set uaa.url                                               "https://uaa.${domain}"
gato config set cf-usb.broker.external_url                            "brokers.${domain}"
gato config set cf-usb.broker.username                                "${cf_usb_username}"
gato config set cf-usb.broker.password                                "${cf_usb_password}"
gato config set cf-usb.management.uaa.secret                          "${uaa_clients_cf_usb_secret}"
gato config set cf-usb.management.uaa.client                          "${cf_usb_uaa_client}"

# Setting certificate values
cat "${ca_path}/intermediate/private/${certs_prefix}-root.chain.pem" | gato config set -f ha_proxy.ssl_pem -
cat "${certs_path}/jwt_signing.pem" | gato config set -f uaa.jwt.signing_key -
cat "${certs_path}/jwt_signing.pub" | gato config set -f uaa.jwt.verification_key -
cat "${certs_path}/jwt_signing.pub" | gato config set -f cf-usb.management.public_key -


