#!/bin/bash

set -o errexit -o nounset

load_env() {
    local dir="${1}"
    for f in $(ls "${dir}"/*.env | sort | grep -vE '/certs\.env$') ; do
        if ! test -e "${f}" ; then
            echo "Invalid environment file ${f}" >&2
            exit 1
        fi
        source "${f}"
        has_env=yes
    done
}

has_env=no

while getopts e: opt ; do
    case "$opt" in
        e)
            if ! test -d "${OPTARG}" ; then
                echo "Invalid -${opt} argument ${OPTARG}, must be a directory" >&2
                exit 1
            fi
            load_env "${OPTARG}"
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ "${1:-}" == "--help" ]]; then
cat <<EOL
Usage: generate_dev_certs.sh <OUTPUT_PATH>
EOL
exit 0
fi

output_path="${1:-}"

if test -z "${output_path}" ; then
  cat <<EOL
  Usage: generate_dev_certs.sh <OUTPUT_PATH>
EOL
  exit 1
fi

if test "${has_env}" = "no" ; then
    load_env "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/settings/"
fi

# Generate a random signing key passphrase
signing_key_passphrase=$(head -c 32 /dev/urandom | xxd -ps -c 32)

# build and install `certstrap` tool if it's not installed
command -v certstrap > /dev/null 2>&1 || {
  buildCertstrap=$(docker run -d golang:1.7 bash -c "go get github.com/square/certstrap")
  docker wait "${buildCertstrap}"
  docker cp "${buildCertstrap}:/go/bin/certstrap" /home/vagrant/bin/
  docker rm "${buildCertstrap}"
}

# Certificate generation
certs_path="/tmp/hcf/certs"
hcf_certs_path="${certs_path}/hcf"
internal_certs_dir="${certs_path}/internal"
output_path="$(readlink --canonicalize-missing "${output_path}")"

# prepare directories
rm -rf ${certs_path}
mkdir -p ${certs_path}

# generate cf ha_proxy certs
# Source: https://github.com/cloudfoundry/cf-release/blob/master/example_manifests/README.md#dns-configuration
rm -rf ${hcf_certs_path}
mkdir -p ${hcf_certs_path}
cd ${hcf_certs_path}

openssl genrsa -out hcf.key 4096
openssl req -new -key hcf.key -out hcf.csr -sha512 -subj "/CN=*.${DOMAIN}/C=US"
openssl x509 -req -days 3650 -in hcf.csr -signkey hcf.key -out hcf.crt

# Given a host name (e.g. "api"), produce variations based on:
# - Having HCP_SERVICE_DOMAIN_SUFFIX and not ("api", "api.hcf")
# - Wildcard and not ("api", "*.api")
# - Include "COMPONENT.*.svc", "COMPONENT.*.svc.cluster", "COMPONENT.*.svc.cluster.hcp"
#   Where * is one of hcf, hcf1, hcf2, hcf3, hcf4, hcf5
make_domains() {
    local host_name="$1"
    local result="${host_name},*.${host_name}"
    local i
    for (( i = 0; i < 10; i++ )) ; do
        result="${result},${host_name}-${i}.${host_name}-pod"
    done
    local cluster_name
    for cluster_name in "" .cluster.local .cluster.hcp ; do
        local instance_name
        for instance_name in hcf hcf1 hcf2 hcf3 hcf4 hcf5 ; do
            result="${result},${host_name}.${instance_name}.svc${cluster_name}"
            result="${result},*.${host_name}.${instance_name}.svc${cluster_name}"
            for (( i = 0; i < 10; i++ )) ; do
                result="${result},${host_name}-${i}.${host_name}-pod.${instance_name}.svc${cluster_name}"
            done
        done
    done
    if test -n "${HCP_SERVICE_DOMAIN_SUFFIX:-}" ; then
        result="${result},$(tr -d '[[:space:]]' <<EOF
        ${host_name}.${HCP_SERVICE_DOMAIN_SUFFIX},
        *.${host_name}.${HCP_SERVICE_DOMAIN_SUFFIX}
EOF
    )"
    fi
    echo "${result}"
}

make_ha_domains() {
    make_domains "$1"
}

# generate JWT certs
openssl genrsa -out "${certs_path}/jwt_signing.pem" -passout pass:"${signing_key_passphrase}" 4096
openssl rsa -in "${certs_path}/jwt_signing.pem" -outform PEM -passin pass:"${signing_key_passphrase}" -pubout -out "${certs_path}/jwt_signing.pub"

# Instructions from https://github.com/cloudfoundry-incubator/diego-release#generating-tls-certificates

# Generate internal CA
certstrap --depot-path "${internal_certs_dir}" init --common-name "internalCA" --passphrase "${signing_key_passphrase}" --years 10

# generate AUCTIONEER_REP certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name auctioneer_rep --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign auctioneer_rep --CA internalCA --passphrase "${signing_key_passphrase}"

# generate AUCTIONEER_SERVER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name auctioneer_server --domain "$(make_domains "diego-brain")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign auctioneer_server --CA internalCA --passphrase "${signing_key_passphrase}"

# generate BBS_AUCTIONEER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name bbs_auctioneer --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign bbs_auctioneer --CA internalCA --passphrase "${signing_key_passphrase}"

# generate BBS_CLIENT certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name bbs_client --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign bbs_client --CA internalCA --passphrase "${signing_key_passphrase}"

# generate BBS_REP certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name bbs_rep --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign bbs_rep --CA internalCA --passphrase "${signing_key_passphrase}"

# generate BBS_SERVER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name bbs_server --domain "$(make_domains "diego-database")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign bbs_server --CA internalCA --passphrase "${signing_key_passphrase}"

# generate DOPPLER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name doppler --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign doppler --CA internalCA --passphrase "${signing_key_passphrase}"

# generate METRON certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name metron --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign metron --CA internalCA --passphrase "${signing_key_passphrase}"

# generate REP_SERVER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name rep_server --domain "$(make_ha_domains "diego-cell")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign rep_server --CA internalCA --passphrase "${signing_key_passphrase}"

# generate SAML_SERVICEPROVIDER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name saml_serviceprovider --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign saml_serviceprovider --CA internalCA --passphrase "${signing_key_passphrase}"

# generate TRAFFICCONTROLLER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name trafficcontroller --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign trafficcontroller --CA internalCA --passphrase "${signing_key_passphrase}"

# generate SSO routing certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name hcf-sso --domain "$(make_domains "hcf-sso")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign hcf-sso --CA internalCA --passphrase "${signing_key_passphrase}"
cat ${internal_certs_dir}/hcf-sso.crt ${internal_certs_dir}/hcf-sso.key > ${internal_certs_dir}/sso_routing.key
cp ${internal_certs_dir}/hcf-sso.crt ${internal_certs_dir}/sso_routing.crt

# generate ETCD certs (Instructions from https://github.com/cloudfoundry-incubator/diego-release#generating-tls-certificates)
certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdServer" --domain "$(make_ha_domains "etcd")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdServer --CA internalCA --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdClient" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdClient --CA internalCA --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdPeer" --domain "$(make_ha_domains "etcd")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdPeer --CA internalCA --passphrase "${signing_key_passphrase}"

# generate Consul certs (Instructions from https://github.com/cloudfoundry-incubator/consul-release#generating-keys-and-certificates)
# Server certificate to share across the consul cluster
server_cn=server.dc1.hcf
certstrap --depot-path ${internal_certs_dir} request-cert --passphrase '' --common-name ${server_cn}
certstrap --depot-path ${internal_certs_dir} sign ${server_cn} --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f ${internal_certs_dir}/${server_cn}.key ${internal_certs_dir}/server.key
mv -f ${internal_certs_dir}/${server_cn}.csr ${internal_certs_dir}/server.csr
mv -f ${internal_certs_dir}/${server_cn}.crt ${internal_certs_dir}/server.crt

# Server certificate for the demophon component
server_cn=demophon
certstrap --depot-path ${internal_certs_dir} request-cert --passphrase '' --common-name ${server_cn}
certstrap --depot-path ${internal_certs_dir} sign ${server_cn} --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f ${internal_certs_dir}/${server_cn}.key ${internal_certs_dir}/demophon_server.key
mv -f ${internal_certs_dir}/${server_cn}.csr ${internal_certs_dir}/demophon_server.csr
mv -f ${internal_certs_dir}/${server_cn}.crt ${internal_certs_dir}/demophon_server.crt

# Agent certificate to distribute to jobs that access consul
certstrap --depot-path ${internal_certs_dir} request-cert --passphrase '' --common-name 'consul agent'
certstrap --depot-path ${internal_certs_dir} sign consul_agent --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f ${internal_certs_dir}/consul_agent.key ${internal_certs_dir}/agent.key
mv -f ${internal_certs_dir}/consul_agent.csr ${internal_certs_dir}/agent.csr
mv -f ${internal_certs_dir}/consul_agent.crt ${internal_certs_dir}/agent.crt

# generate APP_SSH SSH key
ssh-keygen -b 4096 -t rsa -f "${certs_path}/app_ssh_key" -q -N "" -C hcf-ssh-key
app_ssh_host_key_fingerprint=$(ssh-keygen -lf "${certs_path}/app_ssh_key" | awk '{print $2}')

# generate USB Broker certs
certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "cfUsbBrokerServer" --domain "$(make_domains "cf-usb")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign cfUsbBrokerServer --CA internalCA --passphrase "${signing_key_passphrase}"


# generate uaa certs
uaa_server_key="${certs_path}/uaa_private_key.pem"
uaa_server_crt="${certs_path}/uaa_ca.crt"

certstrap --depot-path "${internal_certs_dir}" request-cert --common-name "uaa" --domain "$(make_domains "uaa")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign "uaa" --CA internalCA --passphrase "${signing_key_passphrase}"
cp "${internal_certs_dir}/uaa.crt" "${uaa_server_crt}"
cat "${internal_certs_dir}/uaa.crt" "${internal_certs_dir}/uaa.key" > "${uaa_server_key}"

# We include hcf.uaa.${DOMAIN} / hcf.login.${DOMAIN} because it's not covered by
# *.${DOMAIN} and it's required by the dev UAA server
server_cn=router_ssl
certstrap --depot-path "${internal_certs_dir}" request-cert --passphrase '' --common-name "${server_cn}" --domain "router,router.${HCP_SERVICE_DOMAIN_SUFFIX:-hcf},${DOMAIN},*.${DOMAIN},hcf.uaa.${DOMAIN},hcf.login.${DOMAIN}"
certstrap --depot-path "${internal_certs_dir}" sign "${server_cn}" --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f "${internal_certs_dir}/${server_cn}.key" "${certs_path}/router_ssl.key"
mv -f "${internal_certs_dir}/${server_cn}.crt" "${certs_path}/router_ssl.cert"
cat "${certs_path}/router_ssl.cert" "${certs_path}/router_ssl.key" > "${certs_path}/ha_proxy.pem"

server_cn=blobstore_tls
certstrap --depot-path "${internal_certs_dir}" request-cert --passphrase '' --common-name "${server_cn}" --domain "$(make_domains "blobstore")"
certstrap --depot-path "${internal_certs_dir}" sign "${server_cn}" --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f "${internal_certs_dir}/${server_cn}.key" "${certs_path}/blobstore_tls.key"
mv -f "${internal_certs_dir}/${server_cn}.crt" "${certs_path}/blobstore_tls.cert"

server_cn=persi_broker_tls
certstrap --depot-path "${internal_certs_dir}" request-cert --passphrase '' --common-name "${server_cn}" --domain "$(make_domains "persi-broker")"
certstrap --depot-path "${internal_certs_dir}" sign "${server_cn}" --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f "${internal_certs_dir}/${server_cn}.key" "${certs_path}/persi_broker_tls.key"
mv -f "${internal_certs_dir}/${server_cn}.crt" "${certs_path}/persi_broker_tls.cert"
cat "${certs_path}/persi_broker_tls.cert" "${certs_path}/persi_broker_tls.key" > "${certs_path}/persi_broker_tls.pem"

APP_SSH_KEY="$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/app_ssh_key")"
APP_SSH_KEY_FINGERPRINT=${app_ssh_host_key_fingerprint}
AUCTIONEER_REP_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/auctioneer_rep.crt")
AUCTIONEER_REP_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/auctioneer_rep.key")
AUCTIONEER_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/auctioneer_server.crt")
AUCTIONEER_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/auctioneer_server.key")
BBS_AUCTIONEER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_auctioneer.crt")
BBS_AUCTIONEER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_auctioneer.key")
BBS_CLIENT_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_client.crt")
BBS_CLIENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_client.key")
BBS_REP_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_rep.crt")
BBS_REP_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_rep.key")
BBS_SERVER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_server.crt")
BBS_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbs_server.key")
BLOBSTORE_TLS_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/blobstore_tls.cert")
BLOBSTORE_TLS_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/blobstore_tls.key")
CF_USB_BROKER_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/cfUsbBrokerServer.crt")
CF_USB_BROKER_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/cfUsbBrokerServer.key")
CONSUL_AGENT_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/agent.crt")
CONSUL_AGENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/agent.key")
CONSUL_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/server.crt")
CONSUL_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/server.key")
DEMOPHON_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/demophon_server.crt")
DEMOPHON_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/demophon_server.key")
DOPPLER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/doppler.crt")
DOPPLER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/doppler.key")
ETCD_CLIENT_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdClient.crt")
ETCD_CLIENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdClient.key")
ETCD_PEER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdPeer.crt")
ETCD_PEER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdPeer.key")
ETCD_SERVER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdServer.crt")
ETCD_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdServer.key")
HAPROXY_SSL_CERT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/ha_proxy.pem")
INTERNAL_CA_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/internalCA.crt")
JWT_SIGNING_PEM=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/jwt_signing.pem")
JWT_SIGNING_PUB=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/jwt_signing.pub")
METRON_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/metron.crt")
METRON_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/metron.key")
PERSI_BROKER_TLS_CERT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/persi_broker_tls.pem")
REP_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/rep_server.crt")
REP_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/rep_server.key")
ROUTER_SSL_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/router_ssl.cert")
ROUTER_SSL_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/router_ssl.key")
SAML_SERVICEPROVIDER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/saml_serviceprovider.crt")
SAML_SERVICEPROVIDER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/saml_serviceprovider.key")
SSO_ROUTE_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/sso_routing.crt")
SSO_ROUTE_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/sso_routing.key")
TRAFFICCONTROLLER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/trafficcontroller.crt")
TRAFFICCONTROLLER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/trafficcontroller.key")
UAA_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${uaa_server_crt}")
UAA_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${uaa_server_key}")

cat <<ENVS > ${output_path}
APP_SSH_KEY=${APP_SSH_KEY}
APP_SSH_KEY_FINGERPRINT=${APP_SSH_KEY_FINGERPRINT}
AUCTIONEER_REP_CERT=${AUCTIONEER_REP_CERT}
AUCTIONEER_REP_KEY=${AUCTIONEER_REP_KEY}
AUCTIONEER_SERVER_CERT=${AUCTIONEER_SERVER_CERT}
AUCTIONEER_SERVER_KEY=${AUCTIONEER_SERVER_KEY}
BBS_AUCTIONEER_CERT=${BBS_AUCTIONEER_CERT}
BBS_AUCTIONEER_KEY=${BBS_AUCTIONEER_KEY}
BBS_CLIENT_CRT=${BBS_CLIENT_CRT}
BBS_CLIENT_KEY=${BBS_CLIENT_KEY}
BBS_REP_CERT=${BBS_REP_CERT}
BBS_REP_KEY=${BBS_REP_KEY}
BBS_SERVER_CRT=${BBS_SERVER_CRT}
BBS_SERVER_KEY=${BBS_SERVER_KEY}
BLOBSTORE_TLS_CERT=${BLOBSTORE_TLS_CERT}
BLOBSTORE_TLS_KEY=${BLOBSTORE_TLS_KEY}
CF_USB_BROKER_SERVER_CERT=${CF_USB_BROKER_SERVER_CERT}
CF_USB_BROKER_SERVER_KEY=${CF_USB_BROKER_SERVER_KEY}
CONSUL_AGENT_CERT=${CONSUL_AGENT_CERT}
CONSUL_AGENT_KEY=${CONSUL_AGENT_KEY}
CONSUL_SERVER_CERT=${CONSUL_SERVER_CERT}
CONSUL_SERVER_KEY=${CONSUL_SERVER_KEY}
DEMOPHON_SERVER_CERT=${DEMOPHON_SERVER_CERT}
DEMOPHON_SERVER_KEY=${DEMOPHON_SERVER_KEY}
DOPPLER_CERT=${DOPPLER_CERT}
DOPPLER_KEY=${DOPPLER_KEY}
ETCD_CLIENT_CRT=${ETCD_CLIENT_CRT}
ETCD_CLIENT_KEY=${ETCD_CLIENT_KEY}
ETCD_PEER_CRT=${ETCD_PEER_CRT}
ETCD_PEER_KEY=${ETCD_PEER_KEY}
ETCD_SERVER_CRT=${ETCD_SERVER_CRT}
ETCD_SERVER_KEY=${ETCD_SERVER_KEY}
HAPROXY_SSL_CERT_KEY=${HAPROXY_SSL_CERT_KEY}
INTERNAL_CA_CERT=${INTERNAL_CA_CERT}
JWT_SIGNING_PEM=${JWT_SIGNING_PEM}
JWT_SIGNING_PUB=${JWT_SIGNING_PUB}
METRON_CERT=${METRON_CERT}
METRON_KEY=${METRON_KEY}
PERSI_BROKER_TLS_CERT_KEY=${PERSI_BROKER_TLS_CERT_KEY}
REP_SERVER_CERT=${REP_SERVER_CERT}
REP_SERVER_KEY=${REP_SERVER_KEY}
ROUTER_SSL_CERT=${ROUTER_SSL_CERT}
ROUTER_SSL_KEY=${ROUTER_SSL_KEY}
SAML_SERVICEPROVIDER_CERT=${SAML_SERVICEPROVIDER_CERT}
SAML_SERVICEPROVIDER_KEY=${SAML_SERVICEPROVIDER_KEY}
SSO_ROUTE_CERT=${SSO_ROUTE_CERT}
SSO_ROUTE_KEY=${SSO_ROUTE_KEY}
TRAFFICCONTROLLER_CERT=${TRAFFICCONTROLLER_CERT}
TRAFFICCONTROLLER_KEY=${TRAFFICCONTROLLER_KEY}
UAA_SERVER_CERT=${UAA_SERVER_CERT}
UAA_SERVER_KEY=${UAA_SERVER_KEY}
ENVS

echo "Keys for ${DOMAIN} wrote to ${output_path}"
