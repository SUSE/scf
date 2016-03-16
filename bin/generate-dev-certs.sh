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
ca_path="$certs_path/ca"
bbs_certs_dir="${certs_path}/diego/bbs"
etcd_certs_dir="${certs_path}/diego/etcd"
etcd_peer_certs_dir="${certs_path}/diego/etcd_peer"
certs_prefix="hcf"
domain="192.168.77.77.nip.io"
output_path="$(readlink --canonicalize-missing "${output_path}")"

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
  -new -x509 -extensions v3_ca \
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
  -new -x509 -extensions v3_ca \
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
  -new -x509 -extensions v3_ca \
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

CERTS_ROOT_CHAIN_PEM=$(sed '$!{:a;N;s/\n/\\n/;ta}' "${ca_path}/intermediate/private/${certs_prefix}-root.chain.pem")
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

APP_SSH_HOST_KEY_FINGERPRINT=${app_ssh_host_key_fingerprint}
ROUTER_SSL_CERT='-----BEGIN CERTIFICATE-----\nMIIDBjCCAe4CCQCz3nn1SWrDdTANBgkqhkiG9w0BAQUFADBFMQswCQYDVQQGEwJB\nVTETMBEGA1UECBMKU29tZS1TdGF0ZTEhMB8GA1UEChMYSW50ZXJuZXQgV2lkZ2l0\ncyBQdHkgTHRkMB4XDTE1MDMwMzE4NTMyNloXDTE2MDMwMjE4NTMyNlowRTELMAkG\nA1UEBhMCQVUxEzARBgNVBAgTClNvbWUtU3RhdGUxITAfBgNVBAoTGEludGVybmV0\nIFdpZGdpdHMgUHR5IEx0ZDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB\nAKtTK9xq/ycRO3fWbk1abunYf9CY6sl0Wlqm9UPMkI4j0itY2OyGyn1YuCCiEdM3\nb8guGSWB0XSL5PBq33e7ioiaH98UEe+Ai+TBxnJsro5WQ/TMywzRDhZ4E7gxDBav\n88ZY+y7ts0HznfxqEIn0Gu/UK+s6ajYcIy7d9L988+hA3K1FSdes8MavXhrI4xA1\nfY21gESfFkD4SsqvrkISC012pa7oVw1f94slIVcAG+l9MMAkatBGxgWAQO6kxk5o\noH1Z5q2m0afeQBfFqzu5lCITLfgTWCUZUmbF6UpRhmD850/LqNtryAPrLLqXxdig\nOHiWqvFpCusOu/4z1uGC5xECAwEAATANBgkqhkiG9w0BAQUFAAOCAQEAV5RAFVQy\n8Krs5c9ebYRseXO6czL9/Rfrt/weiC1XLcDkE2i2yYsBXazMYr58o4hACJwe2hoC\nbihBZ9XnVpASEYHDLwDj3zxFP/bTuKs7tLhP7wz0lo8i6k5VSPAGBq2kjc/cO9a3\nTMmLPks/Xm42MCSWGDnCEX1854B3+JK3CNEGqSY7FYXU4W9pZtHPZ3gBoy0ymSpg\nmpleiY1Tbn5I2X7vviMW7jeviB5ivkZaXtObjyM3vtPLB+ILpa15ZhDSE5o71sjA\njXqrE1n5o/GXHX+1M8v3aJc30Az7QAqWohW/tw5SoiSmVQZWd7gFht9vSzaH2WgO\nLwcpBC7+cUJEww==\n-----END CERTIFICATE-----'
ROUTER_SSL_KEY='-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAq1Mr3Gr/JxE7d9ZuTVpu6dh/0JjqyXRaWqb1Q8yQjiPSK1jY\n7IbKfVi4IKIR0zdvyC4ZJYHRdIvk8Grfd7uKiJof3xQR74CL5MHGcmyujlZD9MzL\nDNEOFngTuDEMFq/zxlj7Lu2zQfOd/GoQifQa79Qr6zpqNhwjLt30v3zz6EDcrUVJ\n16zwxq9eGsjjEDV9jbWARJ8WQPhKyq+uQhILTXalruhXDV/3iyUhVwAb6X0wwCRq\n0EbGBYBA7qTGTmigfVnmrabRp95AF8WrO7mUIhMt+BNYJRlSZsXpSlGGYPznT8uo\n22vIA+ssupfF2KA4eJaq8WkK6w67/jPW4YLnEQIDAQABAoIBAQCDVqpcOoZKK9K8\nBt3eXQKEMJ2ji2cKczFFJ5MEm9EBtoJLCryZbqfSue3Fzpj9pBUEkBpk/4VT5F7o\n0/Vmc5Y7LHRcbqVlRtV30/lPBPQ4V/eWtly/AZDcNsdfP/J1fgPSvaoqCr2ORLWL\nqL/vEfyIeM4GcWy0+JMcPbmABslw9O6Ptc5RGiP98vCLHQh/++sOtj6PH1pt+2X/\nUecv3b1Hk/3Oe+M8ySorJD3KA94QTRnKX+zubkxRg/zCAki+as8rQc/d+BfVG698\nylUT5LVLNuwbWnffY2Zt5x5CDqH01mJnHmxzQEfn68rb3bGFaYPEn9EP+maQijv6\nSsUM9A3lAoGBAODRDRn4gEIxjPICp6aawRrMDlRc+k6IWDF7wudjxJlaxFr2t7FF\nrFYm+jrcG6qMTyq+teR8uHpcKm9X8ax0L6N6gw5rVzIeIOGma/ZuYIYXX2XJx5SW\nSOas1xW6qEIbOMv+Xu9w2SWbhTgyRmtlxxjr2e7gQLz9z/vuTReJpInnAoGBAMMW\nsq5lqUfAQzqxlhTobQ7tnB48rUQvkGPE92SlDj2TUt9phek2/TgRJT6mdcozvimt\nJPhxKg3ioxG8NPmN0EytjpSiKqlxS1R2po0fb75vputfpw16Z8/2Vik+xYqNMTLo\nSpeVkHu7fbtNYEK2qcU44OyOZ/V+5Oo9TuBIFRhHAoGACkqHhwDRHjaWdR2Z/w5m\neIuOvF3lN2MWZm175ouynDKDeoaAsiS2VttB6R/aRFxX42UHfoYXC8LcTmyAK5zF\n8X3SMf7H5wtqBepQVt+Gm5zGSSqLcEnQ3H5c+impOh105CGoxt0rk4Ui/AeRIalv\nC70AJOcvD3eu5aFq9gDe/1ECgYBAhkVbASzYGnMh+pKVH7rScSxto8v6/XBYT1Ez\n7JOlMhD667/qvtFJtgIHkq7qzepbhnTv5x3tscQVnZY34/u9ILpD1s8dc+dibEvx\n6S/gYLVorB5ois/DLMqaobRcew6Gs+XX9RPwmLahOJpZ9mh4XrOmCgPAYtP71YM9\nExpHCQKBgQCMMDDWGMRdFMJgXbx1uMere7OoniBdZaOexjbglRh1rMVSXqzBoU8+\nyhEuHGAsHGWQdSBHnqRe9O0Bj/Vlw2VVEaJeL1ewRHb+jXSnuKclZOJgMsJAvgGm\nSOWIahDrATA4g1T6yLBWQPhj3ZXD3eCMxT1Q3DvpG1DjgvXwmXQJAA==\n-----END RSA PRIVATE KEY-----'

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
UAA_PRIVATE_KEY=${UAA_PRIVATE_KEY}
UAA_CERTIFICATE=${UAA_CERTIFICATE}
ENVS

echo "Keys wrote to ${output_path}"
