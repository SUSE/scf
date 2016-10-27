#!/bin/bash

# This test checks that SSO does push us to the underlying app if we are
# authenticated correctly

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

APP_DIR=go-env
APP_NAME=${APP_DIR}-$(random_suffix)

DESIRED_STRING="INSTANCE_INDEX=0"
SSO_SERVICE="sso-service-test-brain"

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

do_cleanup() {
    # unbind route
    if test -n "${hostname:-}" ; then
        cf unbind-route-service ${CF_DOMAIN} ${SSO_SERVICE} -f --hostname ${hostname}
    fi

    cf delete-service -f ${SSO_SERVICE}

    # cleanup
    cf delete -f ${APP_NAME}
    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}
}
trap do_cleanup EXIT

# create org and space
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# push an app
cd ${DIR}/../test-resources/${APP_DIR}
cf push ${APP_NAME}

url=${APP_NAME}.${CF_DOMAIN}
test -n "${url}"
hostname="${url%%.*}"
test -n "${hostname}"

# Test that the app is working as intended (before SSO)
curl "${url}/env" | grep ${DESIRED_STRING}

# Set up SSO
cf create-service sso-routing default ${SSO_SERVICE}
cf bind-route-service ${CF_DOMAIN} ${SSO_SERVICE} --hostname ${hostname}

# SSO only applies after restaging
cf restage ${APP_NAME}

# Check that the output is correct
oauth_token="$(cf oauth-token | cut -d ' ' -f 2-)" # Drop the "bearer" prefix
curl --cookie "ssoCookie=${oauth_token}" "${url}/env" 1>/tmp/${APP_NAME}.log

if ! grep ${DESIRED_STRING} /tmp/${APP_NAME}.log ; then
    printf "%bERROR%b SSO failed to have expected output" "${RED}" "${NORMAL}"
    command="${me} curl --cookie ssoCookie=${oauth_token:0:8}... ${url}/env"
    echo "SSO failed to have expected output"
    echo "${command} headers:"
    cat /tmp/${APP_NAME}.header
    echo "${command} body:"
    cat /tmp/${APP_NAME}.log
fi
