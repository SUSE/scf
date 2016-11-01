#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

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
APP_DIR=node-env
APP_NAME=${APP_DIR}-$(random_suffix)
APP_TMP=$(mktemp -dt 008_appversion.XXXXXX)

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cd ;# get of the APP_TMP working directory for clean deletion.
    rm -rf "${APP_TMP}"
    cf delete -f ${APP_NAME}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# Save application code, we will modify it.
cp -rf ${SELFDIR}/../test-resources/${APP_DIR} ${APP_TMP}
cd ${APP_TMP}/${APP_DIR}

# push an app to version
cf push ${APP_NAME}

# verify it is the unmodified version
curl ${APP_NAME}.${CF_DOMAIN} | grep "HPE Helion Stackato"

# get version of the first instance
version=$(cf list-versions ${APP_NAME} | awk '/^0 / {print $2}')

# push the app again, slightly modified
sed -i 's/HPE Helion Stackato/Test Brain/' index.html
cf push ${APP_NAME}

# verify it is the modified version
curl ${APP_NAME}.${CF_DOMAIN} | grep "Test Brain"

# rollback to unmodified version
cf rollback ${APP_NAME} ${version}

# verify it is the unmodified version again
curl ${APP_NAME}.${CF_DOMAIN} | grep "HPE Helion Stackato"
