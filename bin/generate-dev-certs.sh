#!/bin/bash

set -e
set -u

if [[ "$1" == "--help" ]]; then
cat <<EOL
Usage: generate_dev_certs.sh <SIGNING_KEY_PASSPHRASE> <OUTPUT_PATH>
EOL
exit 0
fi

signing_key_passphrase="$1"
output_path="$2"

if [ -z "$signing_key_passphrase" ] || [ -z "$output_path" ] ; then
  cat <<EOL
  Usage: generate_dev_certs.sh <SIGNING_KEY_PASSPHRASE> <OUTPUT_PATH>
EOL
  exit 1
fi

BINDIR=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )/../container-host-files/opt/hcf/bin" && pwd )/"`

. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/dev-settings.env"

# Certificate generation
certs_path="/tmp/hcf/certs"
hcf_certs_path="$certs_path/hcf"
bbs_certs_dir="${certs_path}/diego/bbs"
etcd_certs_dir="${certs_path}/diego/etcd"
etcd_peer_certs_dir="${certs_path}/diego/etcd_peer"
domain="192.168.77.77.nip.io"
output_path="$(readlink --canonicalize-missing "${output_path}")"

# prepare directories
rm -rf ${certs_path}
mkdir -p ${certs_path}

# generate cf ha_proxy certs
# Source: https://github.com/cloudfoundry/cf-release/blob/master/example_manifests/README.md#dns-configuration
rm -rf $hcf_certs_path
mkdir -p $hcf_certs_path
cd $hcf_certs_path

openssl genrsa -out hcf.key 4096
openssl req -new -key hcf.key -out hcf.csr -sha512 -subj "/CN=*.${domain}/C=US"
openssl x509 -req -in hcf.csr -signkey hcf.key -out hcf.crt
cat hcf.crt hcf.key > hcf.pem

# generate JWT certs
openssl genrsa -out "${certs_path}/jwt_signing.pem" -passout pass:"${signing_key_passphrase}" 4096
openssl rsa -in "${certs_path}/jwt_signing.pem" -outform PEM -passin pass:"${signing_key_passphrase}" -pubout -out "${certs_path}/jwt_signing.pub"

# generate BBS certs
rm -rf $bbs_certs_dir
mkdir -p $bbs_certs_dir

cd $bbs_certs_dir
mkdir -p private certs newcerts crl
touch index.txt
printf "%024d" $(date +%s%N) > serial

openssl req -config "${BINDIR}/cert/diego-bbs.cnf" \
  -new -x509 -days 3650 -extensions v3_ca \
  -passout pass:"${signing_key_passphrase}" \
  -subj "/CN=${DIEGO_DATABASE_HOST}/" \
  -keyout "${bbs_certs_dir}/private/bbs-ca.key" -out "${bbs_certs_dir}/certs/bbs-ca.crt"

openssl req -config "${BINDIR}/cert/diego-bbs.cnf" \
    -new -nodes \
    -subj "/CN=${DIEGO_DATABASE_HOST}/" \
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

# generate ETCD certs
rm -rf $etcd_certs_dir
mkdir -p $etcd_certs_dir

cd $etcd_certs_dir
mkdir -p private certs newcerts crl
touch index.txt
printf "%024d" $(date +%s%N) > serial

openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
  -new -x509 -days 3650 -extensions v3_ca \
  -passout pass:"${signing_key_passphrase}" \
  -subj "/CN=${DIEGO_DATABASE_HOST}/" \
  -keyout "${etcd_certs_dir}/private/etcd-ca.key" -out "${etcd_certs_dir}/certs/etcd-ca.crt"

openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
    -new -nodes \
    -subj "/CN=${DIEGO_DATABASE_HOST}/" \
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

# generate ETCD peer certs
rm -rf $etcd_peer_certs_dir
mkdir -p $etcd_peer_certs_dir

cd $etcd_peer_certs_dir
mkdir -p private certs newcerts crl
touch index.txt
printf "%024d" $(date +%s%N) > serial

openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
  -new -x509 -days 3650 -extensions v3_ca \
  -passout pass:"${signing_key_passphrase}" \
  -subj "/CN=${DIEGO_DATABASE_HOST}/" \
  -keyout "${etcd_peer_certs_dir}/private/etcd-ca.key" -out "${etcd_peer_certs_dir}/certs/etcd-ca.crt"

openssl req -config "${BINDIR}/cert/diego-etcd.cnf" \
    -new -nodes \
    -subj "/CN=${DIEGO_DATABASE_HOST}/" \
    -keyout "${etcd_peer_certs_dir}/private/etcd-peer.key" -out "${etcd_peer_certs_dir}/etcd-peer.csr"

openssl ca -config "${BINDIR}/cert/diego-etcd.cnf" \
  -extensions etcd_peer -batch \
  -passin pass:"${signing_key_passphrase}" \
  -keyfile "${etcd_peer_certs_dir}/private/etcd-ca.key" \
  -cert "${etcd_peer_certs_dir}/certs/etcd-ca.crt" \
  -out "${etcd_peer_certs_dir}/certs/etcd-peer.crt" -infiles "${etcd_peer_certs_dir}/etcd-peer.csr"

# generate SSH Host certs
ssh-keygen -b 4096 -t rsa -f "${certs_path}/ssh_key" -q -N "" -C hcf-ssh-key
app_ssh_host_key_fingerprint=$(ssh-keygen -lf "${certs_path}/ssh_key" | awk '{print $2}')

# generate uaa certs

uaa_server_key="${certs_path}/uaa_private_key.pem"
uaa_server_csr="${certs_path}/uaa_server.csr"
uaa_server_crt="${certs_path}/uaa_ca.crt"

# (Instructions from github.com/cloudfoundry/uaa-release:)
# 1. Generate your private key with any passphrase
openssl genrsa -aes256 -out ${uaa_server_key} -passout pass:"${signing_key_passphrase}" 1024
# 2. Remove passphrase from key
openssl rsa -in ${uaa_server_key} -out ${uaa_server_key} -passin pass:"${signing_key_passphrase}"
# 3. Generate certificate signing request for CA
openssl req -x509 -sha256 -new -key ${uaa_server_key} -out ${uaa_server_csr} -subj "/CN=${DIEGO_DATABASE_HOST}/"
# 4. Generate self-signed certificate with 365 days expiry-time
openssl x509 -sha256 -days 365 -in ${uaa_server_csr} -signkey ${uaa_server_key} -out ${uaa_server_crt}

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -keyout "${certs_path}/router_ssl.key" -out "${certs_path}/router_ssl.cert"

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -keyout "${certs_path}/blobstore_tls.key" -out "${certs_path}/blobstore_tls.cert"

CERTS_ROOT_CHAIN_PEM=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/hcf/hcf.pem")
JWT_SIGNING_PEM=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/jwt_signing.pem")
JWT_SIGNING_PUB=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/jwt_signing.pub")
ETCD_PEER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_peer_certs_dir}/private/etcd-peer.key")
ETCD_PEER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_peer_certs_dir}/certs/etcd-peer.crt")
ETCD_PEER_CA_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_peer_certs_dir}/certs/etcd-ca.crt")
ETCD_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_certs_dir}/private/etcd-server.key")
ETCD_CLIENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_certs_dir}/private/etcd-client.key")
ETCD_SERVER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_certs_dir}/certs/etcd-server.crt")
ETCD_CLIENT_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_certs_dir}/certs/etcd-client.crt")
ETCD_CA_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${etcd_certs_dir}/certs/etcd-ca.crt")
BBS_SERVER_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${bbs_certs_dir}/private/bbs-server.key")
BBS_CLIENT_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${bbs_certs_dir}/private/bbs-client.key")
BBS_SERVER_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${bbs_certs_dir}/certs/bbs-server.crt")
BBS_CLIENT_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${bbs_certs_dir}/certs/bbs-client.crt")
BBS_CA_CRT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${bbs_certs_dir}/certs/bbs-ca.crt")
SSH_KEY="$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/ssh_key")"
UAA_PRIVATE_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/uaa_private_key.pem")
UAA_CERTIFICATE=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/uaa_ca.crt")
ROUTER_SSL_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/router_ssl.cert")
ROUTER_SSL_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/router_ssl.key")
BLOBSTORE_TLS_CERT=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/blobstore_tls.cert")
BLOBSTORE_TLS_KEY=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${certs_path}/blobstore_tls.key")

APP_SSH_HOST_KEY_FINGERPRINT=${app_ssh_host_key_fingerprint}

cat <<ENVS > $output_path
CERTS_ROOT_CHAIN_PEM=${CERTS_ROOT_CHAIN_PEM}
JWT_SIGNING_PEM=${JWT_SIGNING_PEM}
JWT_SIGNING_PUB=${JWT_SIGNING_PUB}
ETCD_PEER_KEY=${ETCD_PEER_KEY}
ETCD_PEER_CRT=${ETCD_PEER_CRT}
ETCD_PEER_CA_CRT=${ETCD_PEER_CA_CRT}
ETCD_SERVER_KEY=${ETCD_SERVER_KEY}
ETCD_CLIENT_KEY=${ETCD_CLIENT_KEY}
ETCD_SERVER_CRT=${ETCD_SERVER_CRT}
ETCD_CLIENT_CRT=${ETCD_CLIENT_CRT}
ETCD_CA_CRT=${ETCD_CA_CRT}
BBS_SERVER_KEY=${BBS_SERVER_KEY}
BBS_CLIENT_KEY=${BBS_CLIENT_KEY}
BBS_SERVER_CRT=${BBS_SERVER_CRT}
BBS_CLIENT_CRT=${BBS_CLIENT_CRT}
BBS_CA_CRT=${BBS_CA_CRT}
SSH_KEY=${SSH_KEY}
APP_SSH_HOST_KEY_FINGERPRINT=${APP_SSH_HOST_KEY_FINGERPRINT}
ROUTER_SSL_CERT=${ROUTER_SSL_CERT}
ROUTER_SSL_KEY=${ROUTER_SSL_KEY}
BLOBSTORE_TLS_CERT=${BLOBSTORE_TLS_CERT}
BLOBSTORE_TLS_KEY=${BLOBSTORE_TLS_KEY}
UAA_PRIVATE_KEY=${UAA_PRIVATE_KEY}
UAA_CERTIFICATE=${UAA_CERTIFICATE}
ENVS

echo "Keys wrote to ${output_path}"
