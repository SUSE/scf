#!/bin/bash

set -e

if [[ "$1" == "--help" ]]; then
cat <<EOL
Usage: generate_dev_certs.sh <OUTPUT_PATH>
EOL
exit 0
fi

output_path="$1"

set -u

if test -z "${output_path}" ; then
  cat <<EOL
  Usage: generate_dev_certs.sh <OUTPUT_PATH>
EOL
  exit 1
fi

# Generate a random signing key passphrase
signing_key_passphrase=$(head -c 32 /dev/urandom | xxd -ps -c 32)

# build and install `certstrap` tool if it's not installed
command -v certstrap > /dev/null 2>&1 || {
  buildCertstrap=$(docker run -d golang:1.6 bash -c "go get github.com/square/certstrap")
  docker wait "${buildCertstrap}"
  docker cp "${buildCertstrap}:/go/bin/certstrap" /home/vagrant/bin/
  docker rm "${buildCertstrap}"
}

. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/settings-dev/settings.env"
. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/settings-dev/hosts.env"

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
cat hcf.crt hcf.key > hcf.pem

# generate JWT certs
openssl genrsa -out "${certs_path}/jwt_signing.pem" -passout pass:"${signing_key_passphrase}" 4096
openssl rsa -in "${certs_path}/jwt_signing.pem" -outform PEM -passin pass:"${signing_key_passphrase}" -pubout -out "${certs_path}/jwt_signing.pub"

# Generate internal CA
certstrap --depot-path "${internal_certs_dir}" init --common-name "internalCA" --passphrase "${signing_key_passphrase}" --years 10

# generate BBS certs (Instructions from https://github.com/cloudfoundry-incubator/diego-release#generating-tls-certificates)
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name "bbsServer"  --domain "*.diego-database.hcf,diego-database.hcf,diego-database,*.diego-database,*.diego-database-int.hcf,diego-database-int.hcf,diego-database-int,*.diego-database-int"  --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign bbsServer  --CA internalCA  --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert  --common-name "bbsClient"  --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign bbsClient  --CA internalCA  --passphrase "${signing_key_passphrase}"


# generate SSO routing certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name hcf-sso.hcf --domain "hcf-sso,hcf-sso.hcf" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign hcf-sso.hcf --CA internalCA --passphrase "${signing_key_passphrase}"
cat ${internal_certs_dir}/hcf-sso.hcf.crt ${internal_certs_dir}/hcf-sso.hcf.key > ${internal_certs_dir}/sso_routing.key
cp ${internal_certs_dir}/hcf-sso.hcf.crt ${internal_certs_dir}/sso_routing.crt

# generate ETCD certs (Instructions from https://github.com/cloudfoundry-incubator/diego-release#generating-tls-certificates)
certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdServer"  --domain "*.diego-database.hcf,diego-database.hcf,diego-database,*.diego-database,*.diego-database-int.hcf,diego-database-int.hcf,diego-database-int,*.diego-database-int"  --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdServer  --CA internalCA  --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert  --common-name "etcdClient"  --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdClient  --CA internalCA  --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdPeer"  --domain "*.diego-database.hcf,diego-database.hcf,diego-database,*.diego-database,*.diego-database-int.hcf,diego-database-int.hcf,diego-database-int,*.diego-database-int"  --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdPeer  --CA internalCA  --passphrase "${signing_key_passphrase}"

# generate Consul certs (Instructions from https://github.com/cloudfoundry-incubator/consul-release#generating-keys-and-certificates)
# Server certificate to share across the consul cluster
server_cn=server.dc1.hcf
certstrap --depot-path ${internal_certs_dir} request-cert --passphrase '' --common-name ${server_cn}
certstrap --depot-path ${internal_certs_dir} sign ${server_cn} --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f ${internal_certs_dir}/${server_cn}.key ${internal_certs_dir}/server.key
mv -f ${internal_certs_dir}/${server_cn}.csr ${internal_certs_dir}/server.csr
mv -f ${internal_certs_dir}/${server_cn}.crt ${internal_certs_dir}/server.crt

# Agent certificate to distribute to jobs that access consul
certstrap --depot-path ${internal_certs_dir} request-cert --passphrase '' --common-name 'consul agent'
certstrap --depot-path ${internal_certs_dir} sign consul_agent --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f ${internal_certs_dir}/consul_agent.key ${internal_certs_dir}/agent.key
mv -f ${internal_certs_dir}/consul_agent.csr ${internal_certs_dir}/agent.csr
mv -f ${internal_certs_dir}/consul_agent.crt ${internal_certs_dir}/agent.crt

# generate SSH Host certs
ssh-keygen -b 4096 -t rsa -f "${certs_path}/ssh_key" -q -N "" -C hcf-ssh-key
app_ssh_host_key_fingerprint=$(ssh-keygen -lf "${certs_path}/ssh_key" | awk '{print $2}')

# generate uaa certs

uaa_server_key="${certs_path}/uaa_private_key.pem"
uaa_server_crt="${certs_path}/uaa_ca.crt"

certstrap --depot-path "${internal_certs_dir}" request-cert --common-name "${UAA_HOST}" --domain "uaa,uaa-int" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign "${UAA_HOST}" --CA internalCA --passphrase "${signing_key_passphrase}"
cp "${internal_certs_dir}/${UAA_HOST}.crt" "${uaa_server_crt}"
cat "${internal_certs_dir}/${UAA_HOST}.crt" "${internal_certs_dir}/${UAA_HOST}.key" > "${uaa_server_key}"

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -keyout "${certs_path}/router_ssl.key" -out "${certs_path}/router_ssl.cert"

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -keyout "${certs_path}/blobstore_tls.key" -out "${certs_path}/blobstore_tls.cert"

CERTS_ROOT_CHAIN_PEM=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/hcf/hcf.pem")
JWT_SIGNING_PEM=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/jwt_signing.pem")
JWT_SIGNING_PUB=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/jwt_signing.pub")
INTERNAL_CA_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/internalCA.crt")
ETCD_PEER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdPeer.key")
ETCD_PEER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdPeer.crt")
ETCD_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdServer.key")
ETCD_CLIENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdClient.key")
ETCD_SERVER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdServer.crt")
ETCD_CLIENT_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/etcdClient.crt")
BBS_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbsServer.key")
BBS_CLIENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbsClient.key")
BBS_SERVER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbsServer.crt")
BBS_CLIENT_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/bbsClient.crt")
SSH_KEY="$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/ssh_key")"
UAA_PRIVATE_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${uaa_server_key}")
UAA_CERTIFICATE=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/uaa_ca.crt")
ROUTER_SSL_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/router_ssl.cert")
ROUTER_SSL_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/router_ssl.key")
BLOBSTORE_TLS_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/blobstore_tls.cert")
BLOBSTORE_TLS_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/blobstore_tls.key")
CONSUL_AGENT_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/agent.crt")
CONSUL_AGENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/agent.key")
CONSUL_SERVER_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/server.crt")
CONSUL_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/server.key")
SSO_ROUTE_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/sso_routing.crt")
SSO_ROUTE_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${internal_certs_dir}/sso_routing.key")

APP_SSH_HOST_KEY_FINGERPRINT=${app_ssh_host_key_fingerprint}

cat <<ENVS > ${output_path}
CERTS_ROOT_CHAIN_PEM=${CERTS_ROOT_CHAIN_PEM}
JWT_SIGNING_PEM=${JWT_SIGNING_PEM}
JWT_SIGNING_PUB=${JWT_SIGNING_PUB}
INTERNAL_CA_CERT=${INTERNAL_CA_CERT}
ETCD_PEER_KEY=${ETCD_PEER_KEY}
ETCD_PEER_CRT=${ETCD_PEER_CRT}
ETCD_PEER_CA_CRT=${INTERNAL_CA_CERT}
ETCD_SERVER_KEY=${ETCD_SERVER_KEY}
ETCD_CLIENT_KEY=${ETCD_CLIENT_KEY}
ETCD_SERVER_CRT=${ETCD_SERVER_CRT}
ETCD_CLIENT_CRT=${ETCD_CLIENT_CRT}
ETCD_CA_CRT=${INTERNAL_CA_CERT}
BBS_SERVER_KEY=${BBS_SERVER_KEY}
BBS_CLIENT_KEY=${BBS_CLIENT_KEY}
BBS_SERVER_CRT=${BBS_SERVER_CRT}
BBS_CLIENT_CRT=${BBS_CLIENT_CRT}
BBS_CA_CRT=${INTERNAL_CA_CERT}
SSH_KEY=${SSH_KEY}
APP_SSH_HOST_KEY_FINGERPRINT=${APP_SSH_HOST_KEY_FINGERPRINT}
ROUTER_SSL_CERT=${ROUTER_SSL_CERT}
ROUTER_SSL_KEY=${ROUTER_SSL_KEY}
BLOBSTORE_TLS_CERT=${BLOBSTORE_TLS_CERT}
BLOBSTORE_TLS_KEY=${BLOBSTORE_TLS_KEY}
UAA_PRIVATE_KEY=${UAA_PRIVATE_KEY}
UAA_CERTIFICATE=${UAA_CERTIFICATE}
CONSUL_CA_CERT=${INTERNAL_CA_CERT}
CONSUL_AGENT_CERT=${CONSUL_AGENT_CERT}
CONSUL_AGENT_KEY=${CONSUL_AGENT_KEY}
CONSUL_SERVER_CERT=${CONSUL_SERVER_CERT}
CONSUL_SERVER_KEY=${CONSUL_SERVER_KEY}
SSO_ROUTE_CA_CERT=${INTERNAL_CA_CERT}
SSO_ROUTE_CERT=${SSO_ROUTE_CERT}
SSO_ROUTE_KEY=${SSO_ROUTE_KEY}
ENVS

echo "Keys for ${DOMAIN} wrote to ${output_path}"
