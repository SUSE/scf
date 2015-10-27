#/bin/bash

set -e 

IMAGE=15.126.242.125:5000/hcf/cf-v217-acceptance_tests
CONSUL=http://127.0.0.1:8501

confset () {
  /opt/hcf/bin/set-config $CONSUL $@ 2>/dev/null 1> /dev/null
}

confdel () {
  curl -s -X DELETE $CONSUL/v1/kv/$1?recurse > /dev/null
}

confget () {
  curl -s $CONSUL/v1/kv/$1?raw
}

echo -n "HCF admin account username: "
read ADMIN_USER
echo -n "HCF admin account password: "
read -s ADMIN_PASSWORD

echo -e "\n"
echo "Setting up config values ..."

SYSTEM_DOMAIN=$(confget hcf/user/system_domain)
APPS_DOMAIN=$(confget hcf/user/app_domains)
API=$(confget hcf/user/cc/srv_api_uri)

CLIENT_SECRET=$(confget hcf/user/uaa/clients/gorouter/secret)
SKIP_SSL_VALIDATION=$(confget hcf/user/ssl/skip_cert_verify)

confset hcf/user/acceptance_tests/api "${API}"
confset hcf/user/acceptance_tests/admin_user "${ADMIN_USER}"
confset hcf/user/acceptance_tests/admin_password "${ADMIN_PASSWORD}"
confset hcf/user/acceptance_tests/apps_domain "${APPS_DOMAIN}"	
confset hcf/user/acceptance_tests/skip_ssl_validation "${SKIP_SSL_VALIDATION}"
confset hcf/user/acceptance_tests/system_domain "${SYSTEM_DOMAIN}"
confset hcf/user/acceptance_tests/client_secret "${CLIENT_SECRET}"

confset hcf/user/acceptance_tests/include_sso "true"
confset hcf/user/acceptance_tests/include_operator "false"
confset hcf/user/acceptance_tests/include_logging "true"
confset hcf/user/acceptance_tests/include_security_groups "true"
confset hcf/user/acceptance_tests/include_internet_dependent "true"
confset hcf/user/acceptance_tests/include_services "true"
confset hcf/user/acceptance_tests/include_v3 "false"
confset hcf/user/acceptance_tests/include_routing "false"
confset hcf/user/acceptance_tests/use_diego "false"

confset hcf/user/acceptance_tests/nodes "1"
confset hcf/user/acceptance_tests/verbose "false"

{
  set -e
  mkdir -p $(pwd)/hcf/tests/acceptance

  docker run \
    -it \
    --net hcf \
    --name acceptance_tests \
    -v $(pwd)/hcf/tests/acceptance/:/var/vcap/sys/log/ \
    $IMAGE \
    http://hcf-consul-server.hcf:8501
} || {
  echo "Failed."
}

echo "Cleaning up ..."
confdel hcf/user/acceptance_tests
docker rm --force acceptance_tests

