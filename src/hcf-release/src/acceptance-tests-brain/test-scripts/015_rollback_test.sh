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
UPSINAME=upsi-$(random_suffix)
TMP=$(mktemp -t 015_rollback.XXXXXX)
APP_TMP=$(mktemp -dt 015_rollback_app.XXXXXX)
INDEX="${SELFDIR}/../test-resources/${APP_DIR}/index.html"

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cd ;# get of the APP_TMP working directory for clean deletion.
    rm -rf "${APP_TMP}"
    rm "${TMP}"

    cf delete -f ${APP_NAME}
    cf delete-service -f ${UPSINAME}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

verify() {
    name="$1"
    # verify the active version
    curl ${APP_NAME}.${CF_DOMAIN} | grep "$name"

    # verify user environment
    cf env ${APP_NAME} > ${TMP}
    grep "TEST1: FOO" ${TMP}
    grep "FOO: BAR"   ${TMP}
    grep "BAR: SLOW"  ${TMP}

    # verify memory
    cf app ${APP_NAME} | grep "usage: 32M"

    # verify service/app binding
    cf service ${UPSINAME} | grep "Bound apps: ${APP_NAME}"
}

flip() {
    rev="$1"
    # get version of the first instance
    version=$(cf list-versions ${APP_NAME} | awk "/^${rev} / {print \$2}")
    cf rollback ${APP_NAME} ${version}
}

# helper service for check that rollback does not service bindings
cf create-user-provided-service ${UPSINAME}

# Save application code, we will modify it.
cp -rf ${SELFDIR}/../test-resources/${APP_DIR} ${APP_TMP}
cd ${APP_TMP}/${APP_DIR}

# push an app to version
# do it 5 times, each different (change visible title).
# on first push defer start so that we can setup the bound service and
# the environment variables.

sed 's/HPE Helion Stackato/Test Brain 1/' < ${INDEX} > index.html
cf push ${APP_NAME} --no-start
cf bind-service ${APP_NAME} ${UPSINAME}
cf set-env ${APP_NAME} TEST1 FOO
cf set-env ${APP_NAME} FOO   BAR
cf set-env ${APP_NAME} BAR   SLOW
cf start ${APP_NAME}

sed 's/HPE Helion Stackato/Test Rollback A/' < ${INDEX} > index.html
cf push ${APP_NAME}

sed 's/HPE Helion Stackato/Test Version 3/' < ${INDEX} > index.html
cf push ${APP_NAME}

sed 's/HPE Helion Stackato/Test Modulo B/' < ${INDEX} > index.html
cf push ${APP_NAME}

sed 's/HPE Helion Stackato/Test Gonzo =/' < ${INDEX} > index.html
cf push ${APP_NAME}

# After the setup the revision pushed last should be running
verify "Test Gonzo ="

# rollback and verify that title changes, but bindings, memory, and
# variables don't.
flip 1
verify "Test Rollback A"

flip 3
verify "Test Modulo B"
