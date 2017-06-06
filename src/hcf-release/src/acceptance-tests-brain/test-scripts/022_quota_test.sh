#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)
CF_QUOTA=quota-$(random_suffix)

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}
    cf delete-quota -f ${CF_QUOTA}

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

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete -f ${APP_NAME}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# push an app
cd ${SELFDIR}/../test-resources/${APP_DIR}

cf create-quota ${CF_QUOTA} -r 10 -m 1G

cf set-quota ${CF_ORG} ${CF_QUOTA}

cf push ${APP_NAME}

cf delete -f ${APP_NAME}

cf update-quota ${CF_QUOTA} -m 10M

trap '' EXIT ERR
set +o errexit

result=$(cf push ${APP_NAME})

if [[ $result == *"You have exceeded your organization's memory limit"* ]]; then
 echo "OK Memory test limit"
else
 echo "FAIL"
 exit 1
fi

trap test_cleanup EXIT ERR
set -o errexit

