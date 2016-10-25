#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}
}
trap login_cleanup EXIT ERR

# target, login, create work org and space
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

## # # ## ### Test-specific configuration ### ## # #

# configuration
DOCKERAPP=sso-test-app-$(random_suffix)
DOCKERSERVICE=sso-test-service
TMP=$(mktemp -dt 005_sso.XXXXXX)

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    rm -rf ${TMP}
    cf unbind-route-service ${CF_DOMAIN} ${DOCKERSERVICE} -f --hostname ${DOCKERAPP}
    cf delete-service -f ${DOCKERSERVICE}
    cf delete -f ${DOCKERAPP}
    login_cleanup
}
trap test_cleanup EXIT ERR

# Push a docker app to redirect
cf enable-feature-flag diego_docker
cf push ${DOCKERAPP} -o viovanov/node-env-tiny

cf create-service sso-routing default ${DOCKERSERVICE}
cf bind-route-service ${CF_DOMAIN} ${DOCKERSERVICE} --hostname ${DOCKERAPP}

cf restage ${DOCKERAPP} | tee ${TMP}/log

# Check if the redirect works
url=$(grep urls ${TMP}/log | cut -f 2- -d " " | head -n 1)
loginpage=${TMP}/loginpage
cookies=${TMP}/cookies.txt

login="$(curl -w "%{url_effective}\n" \
    -c ${cookies} -L -s -k -S ${url} \
    -o ${loginpage}).do"

uaa_csrf=$(cat ${loginpage} | \
    sed -n 's/.*name="X-Uaa-Csrf"\s\+value="\([^"]\+\).*/\1/p')

curl -b ${cookies} -c ${cookies} -L -v ${login} \
    --data "username=${CF_USERNAME}&password=${CF_PASSWORD}&X-Uaa-Csrf=${uaa_csrf}" \
    --insecure \
    > ${TMP}/sso.url \
    2>&1

cookie="$(grep "Cookie: ssoCookie" ${TMP}/sso.url)"
httpcode="$(grep "200 OK" ${TMP}/sso.url)"

if [ -z "${cookie}" -o -z "${httpcode}" ];
then
  echo "ERROR: SSO redirect failed"
  exit 1
fi
