#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

DEADLINE=$(expr $(date +%s) + ${TESTBRAIN_TIMEOUT:-300})

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

# configuration
DOCKERAPP=persi-test-app-$(random_suffix)
DOCKERSERVICE=persi-test-service
TMP=$(mktemp -dt 016_persi.XXXXXX)

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    rm -rf "${TMP}"
    cf unbind-service ${DOCKERAPP} ${DOCKERSERVICE}
    cf delete-service -f ${DOCKERSERVICE}
    cf delete -f ${DOCKERAPP}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# Push a docker app
cf enable-feature-flag diego_docker
cf push ${DOCKERAPP} -o viovanov/node-env-tiny -i 2

cf create-service shared-volume default ${DOCKERSERVICE}
cf bind-service ${DOCKERAPP} ${DOCKERSERVICE}

cf restage ${DOCKERAPP}

while [ $(expr $DEADLINE - $(date +%s)) -gt 30 ]; do
    RUNNING=$(cf app ${DOCKERAPP} | grep -E '^#[0-9]+ +running' | wc -l)
    if [ ${RUNNING} -eq 2 ]; then
        break
    fi
    sleep 10
done

PERSI_SERVICE_GUID=$(cf service ${DOCKERSERVICE} --guid)

# Write a file to persi data store from instance 0 of the app
cf ssh -i 0 ${DOCKERAPP} -c "echo dataOnPersiStore > /var/vcap/data/$PERSI_SERVICE_GUID/fileOnPersiStore"

# Read the file from persi data store
cf ssh -i 1 ${DOCKERAPP} -c "cat /var/vcap/data/$PERSI_SERVICE_GUID/fileOnPersiStore" | grep dataOnPersiStore
