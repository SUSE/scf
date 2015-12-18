#/bin/bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

set -e 

# Default to using the same image tag as cf-api
IMAGE_TAG="$${IMAGE_TAG:-${build}}"
IMAGE=helioncf/cf-smoke_tests:$${IMAGE_TAG}
CONSUL="$${CONSUL:-http://127.0.0.1:8501}"

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
ORG=CF-SMOKE-ORG
SPACE=CF-SMOKE-SPACE

confset hcf/user/smoke_tests/api "$${API}"
confset hcf/user/smoke_tests/user "$${ADMIN_USER}"
confset hcf/user/smoke_tests/password "$${ADMIN_PASSWORD}"
confset hcf/user/smoke_tests/apps_domain "$${APPS_DOMAIN}"
confset hcf/user/smoke_tests/org "$${ORG}"
confset hcf/user/smoke_tests/space "$${SPACE}"
confset hcf/user/smoke_tests/skip_ssl_validation $${SKIP_SSL_VALIDATION}

{
  set -e
  mkdir -p $(pwd)/hcf/tests/smoke
  
  docker run \
    -it \
    --net hcf \
    --name smoke_tests \
    -v $(pwd)/hcf/tests/smoke/:/var/vcap/sys/log/ \
    $IMAGE \
    http://hcf-consul-server.hcf:8501
} || {
  echo "Failed."
}

echo "Cleaning up ..."
confdel hcf/user/smoke_tests
docker rm --force smoke_tests

