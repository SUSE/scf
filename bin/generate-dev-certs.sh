#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

load_env() {
    local dir="${1}"
    DOMAIN=${DOMAIN:-}
    if test -n "${DOMAIN}"; then
        tmp=$(mktemp -d)
        cp -r "${dir}/"*.env "${tmp}"
        trap "rm -rf ${tmp}" EXIT
        if test -f "${tmp}/network.env"; then
            sed -i "s/^DOMAIN=.*/DOMAIN=${DOMAIN}/" "${tmp}/network.env"
            sed -i "s/^UAA_HOST=.*/UAA_HOST=uaa.${DOMAIN}/" "${tmp}/network.env"
        fi
        dir="${tmp}"
    fi
    for f in $(ls "${dir}"/*.env | sort | grep -vE '/certs\.env$' | grep -vE '/ca\.env$') ; do
        if ! test -e "${f}" ; then
            echo "Invalid environment file ${f}" >&2
            exit 1
        fi
        # shellcheck disable=SC1090
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

usage() {
    cat <<'EOL'
Usage: "${0:-generate_dev_certs.sh}" [NAMESPACE] <OUTPUT_PATH>
Namespace defaults to `cf`
EOL
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

namespace="${1:-}"
output_path="${2:-}"
if test -z "${output_path}" ; then
    output_path="${namespace}"
    namespace="cf"
fi

if test -z "${output_path}" ; then
    usage
    exit 1
fi

if test "${has_env}" = "no" ; then
    load_env "$( unset CDPATH ; cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/settings/"
fi

# Replace the stubbed-out namespace info
KUBE_SERVICE_DOMAIN_SUFFIX="${KUBE_SERVICE_DOMAIN_SUFFIX:-\${namespace\}.svc.cluster.local}"
KUBE_SERVICE_DOMAIN_SUFFIX="${KUBE_SERVICE_DOMAIN_SUFFIX/\$\{namespace\}/${namespace}}"

# Generate a random signing key passphrase
signing_key_passphrase=$(head -c32 /dev/urandom | base64)

# Certificate generation
certs_path="/tmp/scf/certs"
hcf_certs_path="${certs_path}/hcf"
internal_certs_dir="${certs_path}/internal"
# We can't dynamically allocate a fd because darwin bash is too old.  Hard code to fd9 for now.
output_fd=9
exec 9>"${output_path}"

# prepare directories
rm -rf "${certs_path}"
mkdir -p "${certs_path}"

# Source: https://github.com/cloudfoundry/cf-release/blob/master/example_manifests/README.md#dns-configuration
rm -rf "${hcf_certs_path}"
mkdir -p "${hcf_certs_path}"
cd "${hcf_certs_path}"

openssl genrsa -out hcf.key 4096
openssl req -new -key hcf.key -out hcf.csr -sha512 -subj "/CN=*.${DOMAIN}/C=US"
openssl x509 -req -days 3650 -in hcf.csr -signkey hcf.key -out hcf.crt

# Given a host name (e.g. "api"), produce variations based on:
# - Having KUBE_SERVICE_DOMAIN_SUFFIX and not ("api", "api.cf.svc.cluster.local")
# - Wildcard and not ("api", "*.api")
# - Include "COMPONENT.*.svc", "COMPONENT.*.svc.cluster"
#   Where * is one of hcf, hcf1, hcf2, hcf3, hcf4, hcf5
make_domains() {
    local host_name="$1"
    local result="${host_name},*.${host_name}"
    local i
    for (( i = 0; i < 10; i++ )) ; do
        result="${result},${host_name}-${i}.${host_name}-set"
    done
    # For faking out HA on vagrant
    result="${result},${host_name}-0.${namespace}.svc,*.${host_name}-0.${namespace}.svc"
    local cluster_name
    for cluster_name in "" .cluster.local ; do
        local instance_name
        for instance_name in ${namespace} ${namespace}1 ${namespace}2 ${namespace}3 ${namespace}4 ${namespace}5 ; do
            result="${result},${host_name}.${instance_name}.svc${cluster_name}"
            result="${result},*.${host_name}.${instance_name}.svc${cluster_name}"
            for (( i = 0; i < 10; i++ )) ; do
                result="${result},${host_name}-${i}.${host_name}-set.${instance_name}.svc${cluster_name}"
            done
        done
    done
    if test -n "${DOMAIN:-}" ; then
        result="${result},${host_name}.${DOMAIN},*.${host_name}.${DOMAIN}"
    fi
    if test -n "${KUBE_SERVICE_DOMAIN_SUFFIX:-}" ; then
        result="${result},${host_name}.${KUBE_SERVICE_DOMAIN_SUFFIX}"
        result="${result},*.${host_name}.${KUBE_SERVICE_DOMAIN_SUFFIX}"
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
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name bbs_server --domain "$(make_domains "diego-api")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign bbs_server --CA internalCA --passphrase "${signing_key_passphrase}"

# generate CC_SERVER certs (properties.cc.mutual_tls.{private_key,public_cert})
# The "cloud-controller-ng.service.cf.internal" is present because the syslog-drain-binder
# has that name hardwired into it!
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name api --domain "$(make_domains "api"),cloud-controller-ng.service.cf.internal" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign api --CA internalCA --passphrase "${signing_key_passphrase}"

# generate CC_UPLOADER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name cc_uploader --domain "$(make_ha_domains "cc-uploader")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign cc_uploader --CA internalCA --passphrase "${signing_key_passphrase}"

# generate DOPPLER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name doppler --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign doppler --CA internalCA --passphrase "${signing_key_passphrase}"

# generate METRON certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name metron --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign metron --CA internalCA --passphrase "${signing_key_passphrase}"

# generate REP_SERVER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name rep_server --domain "$(make_ha_domains "diego-cell")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign rep_server --CA internalCA --passphrase "${signing_key_passphrase}"

# generate REP_CLIENT certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name rep_client --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign rep_client --CA internalCA --passphrase "${signing_key_passphrase}"

# generate SYSLOGDRAINBINDER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name syslogdrainbinder --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign syslogdrainbinder --CA internalCA --passphrase "${signing_key_passphrase}"

# generate TPS_CC_CLIENT certs (properties.capi.tps.cc.{client_cert,client_key})
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name tpsCCClient --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign tpsCCClient --CA internalCA --passphrase "${signing_key_passphrase}"

# generate TRAFFICCONTROLLER certs
certstrap --depot-path "${internal_certs_dir}" request-cert --common-name trafficcontroller --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign trafficcontroller --CA internalCA --passphrase "${signing_key_passphrase}"

# generate ETCD certs (Instructions from https://github.com/cloudfoundry-incubator/diego-release#generating-tls-certificates)
certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdServer" --domain "$(make_ha_domains "etcd")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdServer --CA internalCA --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdClient" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdClient --CA internalCA --passphrase "${signing_key_passphrase}"

certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "etcdPeer" --domain "$(make_ha_domains "etcd")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign etcdPeer --CA internalCA --passphrase "${signing_key_passphrase}"

# generate USB certs
certstrap --depot-path "${internal_certs_dir}"  request-cert --common-name "cfUsbBrokerServer" --domain "$(make_domains "cf-usb")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}"  sign cfUsbBrokerServer --CA internalCA --passphrase "${signing_key_passphrase}"

# generate Consul certs (Instructions from https://github.com/cloudfoundry-incubator/consul-release#generating-keys-and-certificates)
# Server certificate to share across the consul cluster
server_cn=server.dc1.${namespace}
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

# generate APP_SSH SSH key
# ATTENTION: Generate the fingerprint in MD5 format
#
# See  https://github.com/cloudfoundry/diego-release/tree/develop/examples/aws#generating-ssh-proxy-host-key-and-fingerprint
# and  https://github.com/cloudfoundry/cli/issues/817
#
ssh-keygen -b 4096 -t rsa -f "${certs_path}/app_ssh_key" -q -N "" -C hcf-ssh-key
awk '{print $2}' "${certs_path}/app_ssh_key.pub" | base64 --decode | openssl md5 -c | awk '{print $NF}' > "${certs_path}/app_ssh_host_key_fingerprint"

server_cn=router_ssl
certstrap --depot-path "${internal_certs_dir}" request-cert --passphrase '' --common-name "${server_cn}" --domain "router,router.${KUBE_SERVICE_DOMAIN_SUFFIX},${DOMAIN},*.${DOMAIN}"
certstrap --depot-path "${internal_certs_dir}" sign "${server_cn}" --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f "${internal_certs_dir}/${server_cn}.key" "${certs_path}/router_ssl.key"
mv -f "${internal_certs_dir}/${server_cn}.crt" "${certs_path}/router_ssl.cert"

server_cn=blobstore_tls
certstrap --depot-path "${internal_certs_dir}" request-cert --passphrase '' --common-name "${server_cn}" --domain "$(make_domains "blobstore")"
certstrap --depot-path "${internal_certs_dir}" sign "${server_cn}" --CA internalCA --passphrase "${signing_key_passphrase}"
mv -f "${internal_certs_dir}/${server_cn}.key" "${certs_path}/blobstore_tls.key"
mv -f "${internal_certs_dir}/${server_cn}.crt" "${certs_path}/blobstore_tls.cert"

# escape_file_contents reads the given file and replaces newlines with the literal string '\n'
escape_file_contents() {
    # Add a backslash at the end of each line, then replace the newline with a literal 'n'
    # (and then remove the new line at the end)
    sed 's@$@\\@' < "$1" | tr '\n' 'n' | sed 's@\\n$@@'
}

# add_env takes the variable name and file path, and adds the corresponding line
# to the output file
add_env() {
    local var_name="${1}"
    local cert_path="${2}"
    # Note that this is always an append (because it's into an open fd)
    echo "${var_name}=$(escape_file_contents "${cert_path}")" >&${output_fd}
}

add_env APP_SSH_KEY               "${certs_path}/app_ssh_key"
add_env APP_SSH_KEY_FINGERPRINT   "${certs_path}/app_ssh_host_key_fingerprint"
add_env AUCTIONEER_REP_CERT       "${internal_certs_dir}/auctioneer_rep.crt"
add_env AUCTIONEER_REP_KEY        "${internal_certs_dir}/auctioneer_rep.key"
add_env AUCTIONEER_SERVER_CERT    "${internal_certs_dir}/auctioneer_server.crt"
add_env AUCTIONEER_SERVER_KEY     "${internal_certs_dir}/auctioneer_server.key"
add_env BBS_AUCTIONEER_CERT       "${internal_certs_dir}/bbs_auctioneer.crt"
add_env BBS_AUCTIONEER_KEY        "${internal_certs_dir}/bbs_auctioneer.key"
add_env BBS_CLIENT_CRT            "${internal_certs_dir}/bbs_client.crt"
add_env BBS_CLIENT_KEY            "${internal_certs_dir}/bbs_client.key"
add_env BBS_REP_CERT              "${internal_certs_dir}/bbs_rep.crt"
add_env BBS_REP_KEY               "${internal_certs_dir}/bbs_rep.key"
add_env BBS_SERVER_CRT            "${internal_certs_dir}/bbs_server.crt"
add_env BBS_SERVER_KEY            "${internal_certs_dir}/bbs_server.key"
add_env BLOBSTORE_TLS_CERT        "${certs_path}/blobstore_tls.cert"
add_env BLOBSTORE_TLS_KEY         "${certs_path}/blobstore_tls.key"
add_env CC_SERVER_CRT             "${internal_certs_dir}/api.crt"
add_env CC_SERVER_KEY             "${internal_certs_dir}/api.key"
add_env CC_UPLOADER_CRT           "${internal_certs_dir}/cc_uploader.crt"
add_env CC_UPLOADER_KEY           "${internal_certs_dir}/cc_uploader.key"
add_env CF_USB_BROKER_SERVER_CERT "${internal_certs_dir}/cfUsbBrokerServer.crt"
add_env CF_USB_BROKER_SERVER_KEY  "${internal_certs_dir}/cfUsbBrokerServer.key"
add_env CONSUL_AGENT_CERT         "${internal_certs_dir}/agent.crt"
add_env CONSUL_AGENT_KEY          "${internal_certs_dir}/agent.key"
add_env CONSUL_SERVER_CERT        "${internal_certs_dir}/server.crt"
add_env CONSUL_SERVER_KEY         "${internal_certs_dir}/server.key"
add_env DOPPLER_CERT              "${internal_certs_dir}/doppler.crt"
add_env DOPPLER_KEY               "${internal_certs_dir}/doppler.key"
add_env ETCD_CLIENT_CRT           "${internal_certs_dir}/etcdClient.crt"
add_env ETCD_CLIENT_KEY           "${internal_certs_dir}/etcdClient.key"
add_env ETCD_PEER_CRT             "${internal_certs_dir}/etcdPeer.crt"
add_env ETCD_PEER_KEY             "${internal_certs_dir}/etcdPeer.key"
add_env ETCD_SERVER_CRT           "${internal_certs_dir}/etcdServer.crt"
add_env ETCD_SERVER_KEY           "${internal_certs_dir}/etcdServer.key"
add_env INTERNAL_CA_CERT          "${internal_certs_dir}/internalCA.crt"
add_env JWT_SIGNING_PEM           "${certs_path}/jwt_signing.pem"
add_env JWT_SIGNING_PUB           "${certs_path}/jwt_signing.pub"
add_env METRON_CERT               "${internal_certs_dir}/metron.crt"
add_env METRON_KEY                "${internal_certs_dir}/metron.key"
add_env REP_SERVER_CERT           "${internal_certs_dir}/rep_server.crt"
add_env REP_SERVER_KEY            "${internal_certs_dir}/rep_server.key"
add_env REP_CLIENT_CERT           "${internal_certs_dir}/rep_client.crt"
add_env REP_CLIENT_KEY            "${internal_certs_dir}/rep_client.key"
add_env ROUTER_SSL_CERT           "${certs_path}/router_ssl.cert"
add_env ROUTER_SSL_KEY            "${certs_path}/router_ssl.key"
add_env SYSLOGDRAINBINDER_CERT    "${internal_certs_dir}/syslogdrainbinder.crt"
add_env SYSLOGDRAINBINDER_KEY     "${internal_certs_dir}/syslogdrainbinder.key"
add_env TPS_CC_CLIENT_CRT         "${internal_certs_dir}/tpsCCClient.crt"
add_env TPS_CC_CLIENT_KEY         "${internal_certs_dir}/tpsCCClient.key"
add_env TRAFFICCONTROLLER_CERT    "${internal_certs_dir}/trafficcontroller.crt"
add_env TRAFFICCONTROLLER_KEY     "${internal_certs_dir}/trafficcontroller.key"

echo "Keys for ${DOMAIN} (service domain ${KUBE_SERVICE_DOMAIN_SUFFIX}) wrote to ${output_path}"
