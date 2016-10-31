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

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

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
    cf env ${APP_NAME} > /tmp/env
    grep "TEST1: FOO" /tmp/env
    grep "FOO: BAR"   /tmp/env
    grep "BAR: SLOW"  /tmp/env

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

cd ${SELFDIR}/../test-resources/${APP_DIR}

# push an app to version
# do it 5 times, each different (change visible title).
# on first push defer start to setup the bound service and envrionment
# variables.
# save index.html and generate the actual index.html from that. it
# makes making the changes easier, having them all start from the
# saved state.

cp index.html index.html.orig

sed 's/HPE Helion Stackato/Test Brain 1/' < index.html.orig > index.html
cf push ${APP_NAME} --no-start
cf bind-service ${APP_NAME} ${UPSINAME}
cf set-env ${APP_NAME} TEST1 FOO
cf set-env ${APP_NAME} FOO   BAR
cf set-env ${APP_NAME} BAR   SLOW
cf start ${APP_NAME}

sed 's/HPE Helion Stackato/Test Rollback A/' < index.html.orig > index.html
cf push ${APP_NAME}

sed 's/HPE Helion Stackato/Test Version 3/' < index.html.orig > index.html
cf push ${APP_NAME}

sed 's/HPE Helion Stackato/Test Modulo B/' < index.html.orig > index.html
cf push ${APP_NAME}

sed 's/HPE Helion Stackato/Test Gonzo =/' < index.html.orig > index.html
cf push ${APP_NAME}

# After the setup the revision pushed last should be running
verify "Test Gonzo ="

# rollback and verify that title changes, but bindings, memory, and
# variables don't.
flip 1
verify "Test Rollback A"

flip 3
verify "Test Modulo B"
