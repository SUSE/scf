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
TMP=$(mktemp -dt 007_usb.XXXXXX)
APP_NAME=php-mysql-$(random_suffix)
HSM_SERVICE_INSTANCE=hsm-service

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    rm -rf "${TMP}"
    cf unbind-service ${APP_NAME} srv${HSM_SERVICE_INSTANCE}
    cf delete -f ${APP_NAME}
    cf delete-service -f srv${HSM_SERVICE_INSTANCE}
    yes | cf usb delete-driver-endpoint de${HSM_SERVICE_INSTANCE}
    cf delete-shared-domain -f ${CF_TCP_DOMAIN}

    # delete hsm_passthrough
    cf delete -f ${HSM_SERVICE_INSTANCE}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# allow tcp routing
cf delete-shared-domain -f ${CF_TCP_DOMAIN} || true

cf create-shared-domain ${CF_TCP_DOMAIN} --router-group default-tcp
cf update-quota default --reserved-route-ports -1

# run hsm passthrough docker
cf enable-feature-flag diego_docker
cf push "${HSM_SERVICE_INSTANCE}" \
    -o "${TESTBRAIN_DOCKER_REGISTRY:+${TESTBRAIN_DOCKER_REGISTRY%/}/}splatform/hcf-usb-sidecar-test" \
    -d "${CF_TCP_DOMAIN}" --random-route \
    --no-start | tee "${TMP}/log"
cf set-env "${HSM_SERVICE_INSTANCE}" SIDECAR_API_KEY string_empty
cf restart "${HSM_SERVICE_INSTANCE}"

# get the random port assigned
port=$(awk "/Binding .* to ${HSM_SERVICE_INSTANCE}/ {print \$2}" < "${TMP}/log" | cut -f 2 -d ':')

# add service
cf usb create-driver-endpoint de${HSM_SERVICE_INSTANCE} \
    https://${CF_TCP_DOMAIN}:${port} string_empty \
    -k -c '{"display_name":"hsm_passtrough"}' \
    | tee "${TMP}/log"

# Wait until the service is responding correctly
workspace_id=$(awk -F: '/New driver endpoint created. ID/ { print $2 }' < "${TMP}/log")
for (( i = 0 ; i < 12 ; i ++ )) ; do
    if curl --fail --silent --header 'X-Sidecar-Token: string_empty' "https://${CF_TCP_DOMAIN}:${port}/workspaces/${workspace_id}" ; then
        break
    fi
    sleep 5
done

# push an app for the service to bind to
cd ${SELFDIR}/../test-resources/php-mysql
cf push ${APP_NAME}

cf create-service de${HSM_SERVICE_INSTANCE} default srv${HSM_SERVICE_INSTANCE} \
    -c '{"display":"hsm_passtrough_acctests_service"}'
cf bind-service ${APP_NAME} srv${HSM_SERVICE_INSTANCE}
cf restage ${APP_NAME}
