#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)
CF_TCP_DOMAIN=${CF_TCP_DOMAIN:-tcp-$(random_suffix).${CF_DOMAIN}}

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}

    set -o errexit
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

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP=${SELFDIR}/../test-resources/node-env
APP_NAME=tcp-route-node-env-$(random_suffix)
TMP=$(mktemp -dt 006_tcprouting.XXXXXX)

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    rm -rf "${TMP}"
    cf unmap-route ${APP_NAME} ${CF_TCP_DOMAIN} --port ${port}
    cf delete-shared-domain -f ${CF_TCP_DOMAIN}
    cf delete -f ${APP_NAME}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

cd ${APP}
cf push ${APP_NAME}

# set up tcp routing
cf delete-shared-domain -f ${CF_TCP_DOMAIN} || true

cf create-shared-domain ${CF_TCP_DOMAIN} --router-group default-tcp
cf update-quota default --reserved-route-ports -1

cf map-route ${APP_NAME} ${CF_TCP_DOMAIN} --random-port | tee ${TMP}/log

# retrieve the assigned random port
port=$(awk '/Route .* has been created/ {print $2}' < ${TMP}/log | cut -f 2 -d ':')

if [ -z "${port}" ]; then
  echo "ERROR: Could not determine the assigned random port number"
  echo "ERROR: Mapping route to random port failed"
  exit 1
fi

# Wait until the application itself is ready
for (( i = 0; i < 12 ; i++ )) ; do
    if curl --fail -s -o /dev/null ${APP_NAME}.${CF_DOMAIN} ; then
        break
    fi
    sleep 5
done

# check that the application works
sleep 5
curl ${CF_TCP_DOMAIN}:${port}
