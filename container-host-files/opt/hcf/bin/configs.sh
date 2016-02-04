#!/bin/bash
set -e

BINDIR=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/"`

local_ip=`${BINDIR}/get_ip`

# Variables and their defaults
public_ip="${public_ip:-$(echo ${local_ip})}"
bulk_api_password="${bulk_api_password:-password}"
ccdb_role_name="${ccdb_role_name:-ccadmin}"
ccdb_role_password="${ccdb_role_password:-ccpassword}"
ccdb_role_tag="${ccdb_role_tag:-admin}"
certs_prefix="${certs_prefix:-hcf}"
cf_usb_username="${cf_usb_username:-broker-admin}"
cf_usb_password="${cf_usb_password:-changeme}"
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
internal_api_password="${internal_api_password:-internal_password}"
internal_api_user="${internal_api_user:-internal_user}"
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
uaa_clients_diego_ssh_proxy_secret="${uaa_clients_diego_ssh_proxy_secret:-ssh_proxy_secret}"
bbs_active_key_label="${bbs_active_key_label:-key1}"
bbs_active_key_passphrase="${bbs_active_key_passphrase:-key1_passphrase}"


uaa_cloud_controller_username_lookup_secret="${uaa_cloud_controller_username_lookup_secret:-cloud_controller_username_lookup_secret}"
uaadb_password="${uaadb_password:-uaaadmin_password}"
uaadb_tag="${uaadb_tag:-admin}"
uaadb_username="${uaadb_username:-uaaadmin}"

# Certificate generation
certs_path="${HOME}/.run/certs"
ca_path="$certs_path/ca"
bbs_certs_dir="${certs_path}/diego/bbs"
etcd_certs_dir="${certs_path}/diego/etcd"
etcd_peer_certs_dir="${certs_path}/diego/etcd_peer"
(
  if [ ! -f $ca_path/intermediate/private/${certs_prefix}-root.chain.pem ] ; then
    # prepare directories
    rm -rf ${certs_path}
    rm -rf ${ca_path}
    mkdir -p ${certs_path}
    mkdir -p ${ca_path}

    cd $ca_path

    cp ${BINDIR}/cert/intermediate_openssl.cnf ./
    cp ${BINDIR}/cert/root_openssl.cnf ./

    # generate ha_proxy certs
    bash ${BINDIR}/cert/generate_root.sh
    bash ${BINDIR}/cert/generate_intermediate.sh
    bash ${BINDIR}/cert/generate_host.sh "${certs_prefix}-root" "*.${domain}"
    cat intermediate/private/${certs_prefix}-root.key.pem > intermediate/private/${certs_prefix}-root.chain.pem
    cat intermediate/certs/${certs_prefix}-root.cert.pem >> intermediate/private/${certs_prefix}-root.chain.pem
  fi

  if [ ! -f ${certs_path}/jwt_signing.pub ] ; then
    # generate JWT certs
    openssl genrsa -out "${certs_path}/jwt_signing.pem" -passout pass:"${signing_key_passphrase}" 4096
    openssl rsa -in "${certs_path}/jwt_signing.pem" -outform PEM -passin pass:"${signing_key_passphrase}" -pubout -out "${certs_path}/jwt_signing.pub"
  fi
) > /dev/null

(
  if [ ! -f ${bbs_certs_dir}/certs/bbs-client.crt ] ; then
    # generate BBS certs
    rm -rf $bbs_certs_dir
    mkdir -p $bbs_certs_dir

    cd $bbs_certs_dir
    mkdir -p private certs newcerts crl
    touch index.txt
    echo '01' > serial

    openssl req -config "${BINDIR}/cert/diego-bbs.cnf" \
      -new -x509 -extensions v3_ca \
      -passout pass:"${signing_key_passphrase}" \
      -subj '/CN=bbs.service.cf.internal/' \
      -keyout "${bbs_certs_dir}/private/bbs-ca.key" -out "${bbs_certs_dir}/certs/bbs-ca.crt"

    openssl req -config "${BINDIR}/cert/diego-bbs.cnf" \
        -new -nodes \
        -subj '/CN=bbs.service.cf.internal/' \
        -keyout "${bbs_certs_dir}/private/bbs-server.key" -out "${bbs_certs_dir}/bbs-server.csr"

    openssl ca -config "${BINDIR}/cert/diego-bbs.cnf" \
      -extensions bbs_server -batch \
      -passin pass:"${signing_key_passphrase}" \
      -keyfile "${bbs_certs_dir}/private/bbs-ca.key" \
      -cert "${bbs_certs_dir}/certs/bbs-ca.crt" \
      -out "${bbs_certs_dir}/certs/bbs-server.crt" -infiles "${bbs_certs_dir}/bbs-server.csr"

    openssl req -config "${BINDIR}/cert/diego-bbs.cnf" \
        -new -nodes \
        -subj '/CN=bbs client/' \
        -keyout "${bbs_certs_dir}/private/bbs-client.key" -out "${bbs_certs_dir}/bbs-client.csr"

    openssl ca -config "${BINDIR}/cert/diego-bbs.cnf" \
      -extensions bbs_client -batch \
      -passin pass:"${signing_key_passphrase}" \
      -keyfile "${bbs_certs_dir}/private/bbs-ca.key" \
      -cert "${bbs_certs_dir}/certs/bbs-ca.crt" \
      -out "${bbs_certs_dir}/certs/bbs-client.crt" -infiles "${bbs_certs_dir}/bbs-client.csr"
  fi

  if [ ! -f ${etcd_certs_dir}/certs/etcd-client.crt ] ; then
    # generate ETCD certs
    rm -rf $etcd_certs_dir
    mkdir -p $etcd_certs_dir

    cd $etcd_certs_dir
    mkdir -p private certs newcerts crl
    touch index.txt
    echo '01' > serial

    openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
      -new -x509 -extensions v3_ca \
      -passout pass:"${signing_key_passphrase}" \
      -subj '/CN=etcd.service.cf.internal/' \
      -keyout "${etcd_certs_dir}/private/etcd-ca.key" -out "${etcd_certs_dir}/certs/etcd-ca.crt"

    openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
        -new -nodes \
        -subj '/CN=etcd.service.cf.internal/' \
        -keyout "${etcd_certs_dir}/private/etcd-server.key" -out "${etcd_certs_dir}/etcd-server.csr"

    openssl ca -config "${BINDIR}/cert/diego-etcd.cnf" \
      -extensions etcd_server -batch \
      -passin pass:"${signing_key_passphrase}" \
      -keyfile "${etcd_certs_dir}/private/etcd-ca.key" \
      -cert "${etcd_certs_dir}/certs/etcd-ca.crt" \
      -out "${etcd_certs_dir}/certs/etcd-server.crt" -infiles "${etcd_certs_dir}/etcd-server.csr"

    openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
        -new -nodes \
        -subj '/CN=diego etcd client/' \
        -keyout "${etcd_certs_dir}/private/etcd-client.key" -out "${etcd_certs_dir}/etcd-client.csr"

    openssl ca -config "${BINDIR}/cert/diego-etcd.cnf" \
      -extensions etcd_client -batch \
      -passin pass:"${signing_key_passphrase}" \
      -keyfile "${etcd_certs_dir}/private/etcd-ca.key" \
      -cert "${etcd_certs_dir}/certs/etcd-ca.crt" \
      -out "${etcd_certs_dir}/certs/etcd-client.crt" -infiles "${etcd_certs_dir}/etcd-client.csr"
  fi

  if [ ! -f ${etcd_peer_certs_dir}/certs/etcd-peer.crt ] ; then
    # generate ETCD peer certs
    rm -rf $etcd_peer_certs_dir
    mkdir -p $etcd_peer_certs_dir

    cd $etcd_peer_certs_dir
    mkdir -p private certs newcerts crl
    touch index.txt
    echo '01' > serial

    openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
      -new -x509 -extensions v3_ca \
      -passout pass:"${signing_key_passphrase}" \
      -subj '/CN=etcd.service.cf.internal/' \
      -keyout "${etcd_peer_certs_dir}/private/etcd-ca.key" -out "${etcd_peer_certs_dir}/certs/etcd-ca.crt"

    openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
        -new -nodes \
        -subj '/CN=etcd.service.cf.internal/' \
        -keyout "${etcd_peer_certs_dir}/private/etcd-peer.key" -out "${etcd_peer_certs_dir}/etcd-peer.csr"

    openssl ca -config "${BINDIR}/cert/diego-etcd.cnf" \
      -extensions etcd_peer -batch \
      -passin pass:"${signing_key_passphrase}" \
      -keyfile "${etcd_peer_certs_dir}/private/etcd-ca.key" \
      -cert "${etcd_peer_certs_dir}/certs/etcd-ca.crt" \
      -out "${etcd_peer_certs_dir}/certs/etcd-peer.crt" -infiles "${etcd_peer_certs_dir}/etcd-peer.csr"
  fi

  if [ ! -f ${certs_path}/ssh_key ] ; then
    # generate SSH Host certs
    ssh-keygen -b 4096 -t rsa -f "${certs_path}/ssh_key" -q -N "" -C hcf-ssh-key
  fi
) > /dev/null
app_ssh_host_key_fingerprint=$(ssh-keygen -lf "${certs_path}/ssh_key" | awk '{print $2}')

which gato >/dev/null || PATH=$PATH:/opt/hcf/bin
# Setting role values
gato config set --role consul                         consul.agent.mode                           'server'
gato config set --role cf-usb                         consul.agent.services.cf_usb                '{}'
gato config set --role uaa                            consul.agent.services.uaa                   '{}'
gato config set --role api                            consul.agent.services.cloud_controller_ng   '{}'
gato config set --role api                            consul.agent.services.routing_api           '{}'
gato config set --role router                         consul.agent.services.gorouter              '{}'
gato config set --role nats                           consul.agent.services.nats                  '{}'
gato config set --role postgres                       consul.agent.services.postgres              '{}'
gato config set --role etcd                           consul.agent.services.etcdlog               '{}'
gato config set --role runner                         consul.agent.services.dea_next              '{}'
gato config set --role diego_database                 consul.agent.services.bbs                   '{}'
gato config set --role diego_database                 consul.agent.services.etcd                  '{}'
gato config set --role diego_brain                    consul.agent.services.auctioneer            '{}'
gato config set --role diego_cc_bridge                consul.agent.services.cc_uploader           '{}'
gato config set --role diego_cc_bridge                consul.agent.services.nsync                 '{}'
gato config set --role diego_cc_bridge                consul.agent.services.stager                '{}'
gato config set --role diego_cc_bridge                consul.agent.services.tps                   '{}'
gato config set --role diego_cell                     consul.agent.services.diego_cell            '{}'
gato config set --role diego_route_emitter            consul.agent.services.diego_route_emitter   '{}'
gato config set --role diego_access                   consul.agent.services.file_server           '{}'
gato config set --role diego_access                   consul.agent.services.ssh_proxy             '{}'
gato config set --role uaa                            route_registrar.routes                      "[{\"name\": \"uaa\", \"port\":\"8080\", \"tags\":{\"component\":\"uaa\"}, \"uris\":[\"uaa.${domain}\", \"*.uaa.${domain}\", \"login.${domain}\", \"*.login.${domain}\"]}]"
gato config set --role api                            route_registrar.routes                      "[{\"name\":\"api\",\"port\":\"9022\",\"tags\":{\"component\":\"CloudController\"},\"uris\":[\"api.${domain}\"]}]"
gato config set --role hm9000                         route_registrar.routes                      "[{\"name\":\"hm9000\",\"port\":\"5155\",\"tags\":{\"component\":\"HM9K\"},\"uris\":[\"hm9000.${domain}\"]}]"
gato config set --role loggregator_trafficcontroller  route_registrar.routes                      "[{\"name\":\"doppler\",\"port\":\"8081\",\"uris\":[\"doppler.${domain}\"]},{\"name\":\"loggregator_trafficcontroller\",\"port\":\"8080\",\"uris\":[\"loggregator.${domain}\"]}]"
gato config set --role doppler                        route_registrar.routes                      "[{\"name\":\"doppler\",\"port\":\"8081\",\"uris\":[\"doppler.${domain}\"]},{\"name\":\"loggregator_trafficcontroller\",\"port\":\"8080\",\"uris\":[\"loggregator.${domain}\"]}]"
gato config set --role cf-usb                         route_registrar.routes                      "[{\"name\":\"usb\",\"port\":\"54053\",\"uris\":[\"usb.${domain}\", \"*.usb.${domain}\"]}, {\"name\":\"broker\",\"port\":\"54054\",\"uris\":[\"brokers.${domain}\", \"*.brokers.${domain}\"]}]"
gato config set --role etcd                           etcd.peer_require_ssl                       'false'
gato config set --role etcd                           etcd.require_ssl                            'false'
gato config set --role etcd                           etcd.cluster                                'null'
gato config set --role etcd                           etcd.peer_key                               'null'
gato config set --role etcd                           etcd.peer_cert                              'null'
gato config set --role etcd                           etcd.peer_ca_cert                           'null'
gato config set --role etcd                           etcd.server_key                             'null'
gato config set --role etcd                           etcd.client_key                             'null'
gato config set --role etcd                           etcd.server_cert                            'null'
gato config set --role etcd                           etcd.client_cert                            'null'
gato config set --role etcd                           etcd.ca_cert                                'null'
gato config set --role api                            etcd.machines                               '["etcdlog.service.cf.internal"]'

# Constants
#gato config set consul.agent.servers.lan                  '["cf-consul.hcf"]'
gato config set nats.machines                             '["nats.service.cf.internal"]'
gato config set etcd_metrics_server.nats.machines         '["nats.service.cf.internal"]'
gato config set etcd_metrics_server.machines              '["nats.service.cf.internal"]'
gato config set nfs_server.share_path                     '/var/vcap/nfs'
gato config set etcd.machines                             '["etcd.service.cf.internal"]'
gato config set etcd.peer_require_ssl                     'true'
gato config set etcd.require_ssl                          'true'
gato config set etcd.cluster                              '[{"instances": 1, "name": "database_z1"}]'
gato config set loggregator.etcd.machines                 '["etcdlog.service.cf.internal"]'
gato config set router.servers.z1                         '["gorouter.service.cf.internal"]'
gato config set dea_next.kernel_network_tuning_enabled    'false'


gato config set diego.auctioneer.bbs.require_ssl          'true'
gato config set diego.auctioneer.bbs.api_location         'bbs.service.cf.internal:8889'
gato config set diego.bbs.auctioneer.api_url              'http://auctioneer.service.cf.internal:9016'
gato config set diego.bbs.etcd.machines                   '["etcd.service.cf.internal"]'
gato config set diego.bbs.etcd.require_ssl                'true'
gato config set diego.bbs.require_ssl                     'true'
gato config set diego.converger.bbs.api_location          'bbs.service.cf.internal:8889'
gato config set diego.converger.bbs.require_ssl           'true'
gato config set diego.converger.log_level                 'debug'
gato config set diego.executor.drain_timeout_in_seconds   '0'
gato config set diego.executor.garden.address             '127.0.0.1:7777'
gato config set diego.executor.garden.network             'tcp'
gato config set diego.executor.log_level                  'debug'
gato config set diego.nsync.bbs.api_location              'bbs.service.cf.internal:8889'
gato config set diego.nsync.bbs.require_ssl               'true'
gato config set diego.nsync.log_level                     'debug'
gato config set diego.rep.bbs.require_ssl                 'true'
gato config set diego.rep.evacuation_timeout_in_seconds   '60'
gato config set diego.rep.log_level                       'debug'
gato config set diego.route_emitter.bbs.api_location      'bbs.service.cf.internal:8889'
gato config set diego.route_emitter.bbs.require_ssl       'true'
gato config set diego.route_emitter.log_level             'debug'
gato config set diego.route_emitter.nats.port             '4222'
gato config set diego.ssh_proxy.bbs.api_location          'bbs.service.cf.internal:8889'
gato config set diego.ssh_proxy.bbs.require_ssl           'true'
gato config set diego.ssh_proxy.enable_cf_auth            'true'
gato config set diego.ssh_proxy.enable_diego_auth         'false'
gato config set diego.stager.bbs.api_location             'bbs.service.cf.internal:8889'
gato config set diego.stager.bbs.require_ssl              'true'
gato config set diego.tps.bbs.api_location                'bbs.service.cf.internal:8889'
gato config set diego.tps.bbs.require_ssl                 'true'
gato config set diego.rep.bbs.api_location                'bbs.service.cf.internal:8889'
gato config set garden.enable_graph_cleanup               'true'
gato config set garden.listen_address                     '0.0.0.0:7777'
gato config set garden.listen_network                     'tcp'
gato config set garden.log_level                          'debug'
gato config set garden.persistent_image_list              '[/var/vcap/packages/rootfs_cflinuxfs2/rootfs]'
gato config set diego.route_emitter.nats.machines         '["nats.service.cf.internal"]'
gato config set diego.rep.zone                            'z1'
gato config set diego.file_server.static_directory        '/var/vcap/packages/'
gato config set cf-usb.configconnectionstring             '127.0.0.1:8500'
gato config set cf-usb.configprovider                     'consulConfigProvider'
gato config set cc.default_to_diego_backend               'true'

# TODO: Take this out, and place our generated CA cert
# into the appropriate /usr/share/ca-certificates folders
# and call update-ca-certificates at container startup
gato config set ssl.skip_cert_verify        'true'
gato config set disk_quota_enabled          'false'
gato config set metron_agent.deployment     "hcf-deployment"
gato config set consul.require_ssl          "false"
gato config set consul.encrypt_keys         "[]"
gato config set cf-usb.skip_tsl_validation  'true'
gato config set cf-usb.management.dev_mode  'true'
gato config set diego.ssl.skip_cert_verify  'true'

# Setting user values
gato config set app_domains                                           "[\"${domain}\"]"
gato config set app_ssh.host_key_fingerprint                          "${app_ssh_host_key_fingerprint}"
gato config set cc.bulk_api_password                                  "${bulk_api_password}"
gato config set cc.db_encryption_key                                  "${db_encryption_key}"
gato config set cc.srv_api_uri                                        "https://api.${domain}"
gato config set cc.staging_upload_user                                "${staging_upload_user}"
gato config set cc.staging_upload_password                            "${staging_upload_password}"
gato config set cc.internal_api_user                                  "${internal_api_user}"
gato config set cc.internal_api_password                              "${internal_api_password}"
gato config set domain                                                "${domain}"
gato config set doppler.zone                                          "${doppler_zone}"
gato config set doppler_endpoint.shared_secret                        "${loggregator_shared_secret}"
gato config set etcd_metrics_server.nats.username                     "${nats_user}"
gato config set etcd_metrics_server.nats.password                     "${nats_password}"
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
gato config set uaa.clients.cf-usb.secret                             "${uaa_clients_cf_usb_secret}"
gato config set uaa.clients.cf-usb.authorized-grant-types             "client_credentials"
gato config set uaa.clients.cf-usb.authorities                        "cloud_controller.admin,usb.management.admin"
gato config set uaa.clients.cf-usb.scope                              "usb.management.admin"
gato config set uaa.clients.app-direct.secret                         "${uaa_clients_app_direct_secret}"
gato config set uaa.clients.developer-console.secret                  "${uaa_clients_developer_console_secret}"
gato config set uaa.clients.notifications.secret                      "${uaa_clients_notifications_secret}"
gato config set uaa.clients.login.secret                              "${uaa_clients_login_secret}"
gato config set uaa.clients.cc_routing.secret                         "${uaa_clients_cc_routing_secret}"
gato config set uaa.clients.doppler.secret                            "${uaa_clients_doppler_secret}"
gato config set uaa.clients.cloud_controller_username_lookup.secret   "${uaa_cloud_controller_username_lookup_secret}"
gato config set uaa.clients.gorouter.secret                           "${uaa_clients_gorouter_secret}"
gato config set uaa.clients.ssh-proxy.secret                          "${uaa_clients_diego_ssh_proxy_secret}"
gato config set uaa.clients.ssh-proxy.authorized-grant-types          "authorization_code"
gato config set uaa.clients.ssh-proxy.scope                           "openid,cloud_controller.read,cloud_controller.write"
gato config set uaa.clients.ssh-proxy.redirect-uri                    "/login"
gato config set uaa.clients.ssh-proxy.autoapprove                     "true"
gato config set uaa.clients.ssh-proxy.override                        "true"
gato config set uaa.scim.users                                        "[\"${cluster_admin_username}|${cluster_admin_password}|${cluster_admin_authorities}\"]"
gato config set system_domain                                         "${domain}"
gato config set traffic_controller.zone                               "${traffic_controller_zone}"
gato config set cf-usb.broker.external_url                            "brokers.${domain}"
gato config set cf-usb.broker.username                                "${cf_usb_username}"
gato config set cf-usb.broker.password                                "${cf_usb_password}"
gato config set cf-usb.management.uaa.secret                          "${uaa_clients_cf_usb_secret}"
gato config set cf-usb.management.uaa.client                          "cf-usb"
gato config set diego.bbs.encryption_keys                             "[{\"label\": \"${bbs_active_key_label}\", \"passphrase\": \"${bbs_active_key_passphrase}\"}]"
gato config set diego.cc_uploader.cc.base_url                         "https://api.${domain}"
gato config set diego.cc_uploader.cc.basic_auth_username              "${internal_api_user}"
gato config set diego.cc_uploader.cc.basic_auth_password              "${internal_api_password}"
gato config set diego.cc_uploader.cc.staging_upload_password          "${staging_upload_password}"
gato config set diego.cc_uploader.cc.staging_upload_user              "${staging_upload_user}"
gato config set diego.nsync.cc.base_url                               "https://api.${domain}"
gato config set diego.nsync.cc.basic_auth_username                    "${internal_api_user}"
gato config set diego.nsync.cc.basic_auth_password                    "${internal_api_password}"
gato config set diego.nsync.cc.staging_upload_password                "${staging_upload_password}"
gato config set diego.nsync.cc.staging_upload_user                    "${staging_upload_user}"
gato config set diego.route_emitter.nats.user                         "${nats_user}"
gato config set diego.route_emitter.nats.password                     "${nats_password}"
gato config set diego.ssh_proxy.servers                               "[\"ssh-proxy.service.cf.internal\"]"
gato config set diego.ssh_proxy.uaa_token_url                         "https://uaa.${domain}/oauth/token"
gato config set diego.ssh_proxy.uaa_secret                            "${uaa_clients_diego_ssh_proxy_secret}"
gato config set diego.stager.cc.base_url                              "https://api.${domain}"
gato config set diego.stager.cc.basic_auth_username                   "${internal_api_user}"
gato config set diego.stager.cc.basic_auth_password                   "${internal_api_password}"
gato config set diego.stager.cc.staging_upload_password               "${staging_upload_password}"
gato config set diego.stager.cc.staging_upload_user                   "${staging_upload_user}"
gato config set diego.tps.cc.base_url                                 "https://api.${domain}"
gato config set diego.tps.cc.basic_auth_username                      "${internal_api_user}"
gato config set diego.tps.cc.basic_auth_password                      "${internal_api_password}"
gato config set diego.tps.cc.staging_upload_password                  "${staging_upload_password}"
gato config set diego.tps.cc.staging_upload_user                      "${staging_upload_user}"
gato config set diego.tps.traffic_controller_url                      "wss://doppler.${domain}:443"
gato config set diego.bbs.active_key_label                            "${bbs_active_key_label}"
gato config set garden.deny_networks                                  "[]"
# TODO: This should be handled in the 'opinions' file, since the ERB templates will generate this value
gato config set hm9000.url                                            "https://hm9000.${domain}"
gato config set uaa.url                                               "https://uaa.${domain}"

# pipecat: prepare files for being stored as a multi-line yaml string
# Assumes `gato config set` verifies values are valid yaml strings, but
# doesn't yaml-encode values for storing in consul.
# Since both simple multi-line strings and literal-(pipe)-introduced
# indented multi-line strings are both valid YAML, we need to convert
# the former into the latter.
function pipecat {
    fname=$1
    echo '|'
    sed 's/^/ /' $fname
}

# Setting certificate values
pipecat "${ca_path}/intermediate/private/${certs_prefix}-root.chain.pem" | gato config set-file ha_proxy.ssl_pem -
pipecat "${certs_path}/jwt_signing.pem" | gato config set-file uaa.jwt.signing_key -
pipecat "${certs_path}/jwt_signing.pub" | gato config set-file uaa.jwt.verification_key -
pipecat "${certs_path}/jwt_signing.pub" | gato config set-file cf-usb.management.public_key -
# Diego certificates
pipecat "${etcd_peer_certs_dir}/private/etcd-peer.key" | gato config set-file etcd.peer_key -
pipecat "${etcd_peer_certs_dir}/certs/etcd-peer.crt" | gato config set-file etcd.peer_cert -
pipecat "${etcd_peer_certs_dir}/certs/etcd-ca.crt" | gato config set-file etcd.peer_ca_cert -
pipecat "${etcd_certs_dir}/private/etcd-server.key" | gato config set-file etcd.server_key -
pipecat "${etcd_certs_dir}/private/etcd-client.key" | gato config set-file etcd.client_key -
pipecat "${etcd_certs_dir}/private/etcd-client.key" | gato config set-file diego.bbs.etcd.client_key -
pipecat "${etcd_certs_dir}/certs/etcd-server.crt" | gato config set-file etcd.server_cert -
pipecat "${etcd_certs_dir}/certs/etcd-client.crt" | gato config set-file etcd.client_cert -
pipecat "${etcd_certs_dir}/certs/etcd-client.crt" | gato config set-file diego.bbs.etcd.client_cert -
pipecat "${etcd_certs_dir}/certs/etcd-ca.crt" | gato config set-file etcd.ca_cert -
pipecat "${etcd_certs_dir}/certs/etcd-ca.crt" | gato config set-file diego.bbs.etcd.ca_cert -
# The "host key" mentioned here is actually an RSA private key file, with no passphrase
pipecat "${certs_path}/ssh_key" | gato config set-file diego.ssh_proxy.host_key -
pipecat "${bbs_certs_dir}/private/bbs-server.key" | gato config set-file diego.bbs.server_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.tps.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.stager.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.ssh_proxy.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.route_emitter.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.rep.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.nsync.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.converger.bbs.client_key -
pipecat "${bbs_certs_dir}/private/bbs-client.key" | gato config set-file diego.auctioneer.bbs.client_key -
pipecat "${bbs_certs_dir}/certs/bbs-server.crt" | gato config set-file diego.bbs.server_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.tps.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.stager.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.ssh_proxy.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.route_emitter.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.rep.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.nsync.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.converger.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-client.crt" | gato config set-file diego.auctioneer.bbs.client_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.tps.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.stager.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.ssh_proxy.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.route_emitter.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.rep.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.nsync.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.converger.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.bbs.ca_cert -
pipecat "${bbs_certs_dir}/certs/bbs-ca.crt" | gato config set-file diego.auctioneer.bbs.ca_cert -



gato config set ccdb.roles                                            "[{\"name\": \"${ccdb_role_name}\", \"password\": \"${ccdb_role_password}\", \"tag\": \"${ccdb_role_tag}\"}]"
gato config set databases.roles                                       "[{\"name\": \"${ccdb_role_name}\", \"password\": \"${ccdb_role_password}\",\"tag\": \"${ccdb_role_tag}\"}, {\"name\": \"${uaadb_username}\", \"password\": \"${uaadb_password}\", \"tag\":\"${uaadb_tag}\"}]"
gato config set uaadb.roles                                           "[{\"name\": \"${uaadb_username}\", \"password\": \"${uaadb_password}\", \"tag\": \"${uaadb_tag}\"}]"


gato config set databases.databases                       '[{"citext":true, "name":"ccdb", "tag":"cc"}, {"citext":true, "name":"uaadb", "tag":"uaa"}]'
gato config set databases.port                            '3306'
gato config set ccdb.port                                 '3306'
gato config set uaadb.port                                '3306'
gato config set ccdb.address                              'mysql-proxy.service.cf.internal'
gato config set databases.address                         'mysql-proxy.service.cf.internal'
gato config set uaadb.address                             'mysql-proxy.service.cf.internal'
gato config set ccdb.db_scheme                              'mysql'
gato config set databases.db_scheme                         'mysql'
gato config set uaadb.db_scheme                             'mysql'


gato config set --role mysql                       consul.agent.services.mysql              '{}'
gato config set --role mysql_proxy                           consul.agent.services.mysql_proxy               '{}'

gato config set --role mysql admin_password 'changeme'
gato config set --role mysql cluster_ips '["mysql.service.cf.internal"]'
gato config set --role mysql database_startup_timeout "300"
gato config set --role mysql external_host '192.168.77.77.nip.io'
gato config set --role mysql network_name 'default'
gato config set --role mysql proxy.api_force_https 'false'
gato config set --role mysql proxy.api_password 'changeme'
gato config set --role mysql proxy.api_username 'proxy_username'
gato config set --role mysql proxy.proxy_ips '["mysql-proxy.service.cf.internal"]'
gato config set --role mysql skip_ssl_validation 'true'
gato config set --role mysql bootstrap_endpoint.username 'bootstrap_user'
gato config set --role mysql bootstrap_endpoint.password 'bootstrap_pass'
gato config set --role mysql seeded_databases "[{\"name\": \"ccdb\",\"username\": \"${ccdb_role_name}\",\"password\": \"${ccdb_role_password}\"},{\"name\": \"uaadb\",\"username\": \"${uaadb_username}\",\"password\": \"${uaadb_password}\"}]"


gato config set --role mysql_proxy admin_password 'changeme'
gato config set --role mysql_proxy cluster_ips '["mysql.service.cf.internal"]'
gato config set --role mysql_proxy database_startup_timeout "300"
gato config set --role mysql_proxy external_host '192.168.77.77.nip.io'
gato config set --role mysql_proxy network_name 'default'
gato config set --role mysql_proxy proxy.api_force_https 'false'
gato config set --role mysql_proxy proxy.api_password 'changeme'
gato config set --role mysql_proxy proxy.api_username 'proxy_username'
gato config set --role mysql_proxy proxy.proxy_ips '["mysql-proxy.service.cf.internal"]'
gato config set --role mysql_proxy skip_ssl_validation 'true'
gato config set --role mysql_proxy bootstrap_endpoint.username 'bootstrap_user'
gato config set --role mysql_proxy bootstrap_endpoint.password 'bootstrap_pass'
gato config set --role mysql_proxy seeded_databases "[{\"name\": \"ccdb\",\"username\": \"${ccdb_role_name}\",\"password\": \"${ccdb_role_password}\"},{\"name\": \"uaadb\",\"username\": \"${uaadb_username}\",\"password\": \"${uaadb_password}\"}]"

echo -e "Your Helion Cloud Foundry endpoint is: \e[1;96mhttps://api.${domain}\e[0m"
echo -e "  Run the following command to target it: \e[1;96mcf api --skip-ssl-validation https://api.${domain}\e[0m"
echo -e "The Universal Service Broker endpoint is: \e[1;96mhttps://usb.${domain}\e[0m"
echo -e "Your administrative credentials are:"
echo -e "  Username: \e[1;96m${cluster_admin_username}\e[0m"
echo -e "  Password: \e[1;96m${cluster_admin_password}\e[0m"