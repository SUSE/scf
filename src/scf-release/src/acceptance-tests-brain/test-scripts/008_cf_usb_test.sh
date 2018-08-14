#!/bin/bash
# # ## ### ##### ######## #############  #####################
## Explanations and overview:

## This test does a lot of setup to determine that the universal
## service broker (cf-usb) is actually working.
#
## 0. A domain for TCP routing is created, to connect all the pieces.
#
## 1. A local mysql server is started as an app and made available
##    through cf TCP routing.
#
## 2. The mysql sidecar is started as an app, configured to talk to
##    the mysql server from (1).
#
## 3. The cf-usb is configured to talk to and use the side car.
#
## 4. Then we can check that mysql appears in the marketplace, create
##    a service from it, and check that this service is viewable too.
#
## In the code below these phases are marked with "--(N)--" where N is
## the step number.
#
## Note, the applications of step 1 and 2 are docker apps. This is why
## the `pre-start.sh` script enables the `diego_docker` feature-flag
## of CF. For step (3) the `pre-start.sh` script extended the `cf`
## client with the `cf-usb-plugin` plugin.

function get_port
{
    file="${1}"
    port="$(awk '/Route .* has been created/ {print $2}' < "${TMP}/${file}" | cut -f 2 -d ':')"
    if [ -z "${port}" ]; then
	echo 1>&2 "ERROR: Could not determine the assigned random port number for $1"
	echo 1>&2 "ERROR: Mapping route to random port failed for $1"
	exit 1
    fi
    echo "${port}"
}

function wait_on_database
{
    # args = port user password
    for (( i = 0; i < 60 ; i++ )) ; do
	if mysql -u"${2}" -p"${3}" -P "${1}" -h "${CF_TCP_DOMAIN}" > /dev/null ; then
            break
	fi
	sleep 5
    done
    # Last try, any error will abort the test
     mysql -u"${2}" -p"${3}" -P "${1}" -h "${CF_TCP_DOMAIN}"
}

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

    cf delete-space -f "${CF_SPACE}"
    cf delete-org   -f "${CF_ORG}"

    set -o errexit
}
trap login_cleanup EXIT ERR

# target, login, create work org and space
cf api --skip-ssl-validation "api.${CF_DOMAIN}"
cf auth "${CF_USERNAME}" "${CF_PASSWORD}"

cf create-org "${CF_ORG}"
cf target -o  "${CF_ORG}"

cf create-space "${CF_SPACE}"
cf target -s    "${CF_SPACE}"

## # # ## ### Test-specific configuration ### ## # #

# Location of the test script. All other assets will be found relative
# to this.
TMP=$(mktemp -dt 008_cf_usb.XXXXXX)

MYSQL_USER=root
MYSQL_PASS=testpass

SERVER_APP=mysql

SIDECAR_API_KEY=secret-key
SIDECAR_APP=msc

SERVICE_TYPE=my-service
SERVICE_INSTANCE=my-db

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    # Reverse order of creation ...
    # - service instance
    # - service type = usb endpoint
    # - msc sidecar app
    # - mysql server app
    # - security groups
    # - tcp routing
    # - temp directory

    cf delete-service -f "${SERVICE_INSTANCE}"
    yes | cf usb-delete-driver-endpoint "${SERVICE_TYPE}"
    cf delete -f "${SIDECAR_APP}"
    cf delete -f "${SERVER_APP}"
    cf unbind-running-security-group internal-services-workaround
    cf unbind-staging-security-group internal-services-workaround
    cf delete-shared-domain -f "${CF_TCP_DOMAIN}"

    rm -rf "${TMP}"

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# --(0)-- Initialize tcp routing

cf delete-shared-domain -f "${CF_TCP_DOMAIN}" || true
cf create-shared-domain    "${CF_TCP_DOMAIN}" --router-group default-tcp
cf update-quota default --reserved-route-ports -1

# --(0.1) -- Initialize a security group to allow for inter-app comms
# Attention: This SG opens the entire internal kube service network.

echo > "${TMP}/internal-services.json" '[{ "destination": "0.0.0.0/0", "protocol": "all" }]'

cf create-security-group       internal-services-workaround "${TMP}/internal-services.json"
cf bind-running-security-group internal-services-workaround
cf bind-staging-security-group internal-services-workaround

## --(1)-- Create and configure the mysql server

# Use MySQL 8.0.3, as MySQL defaults to the sha2 authentication plugin in 8.0.4
# which isn't supported by github.com/go-sql-driver/mysql (the MySQL driver in
# use in the USB broker).
# https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_default_authentication_plugin
# https://github.com/go-sql-driver/mysql/issues/785
cf push --no-start --no-route --health-check-type none "${SERVER_APP}" -o mysql/mysql-server:8.0.3
cf map-route "${SERVER_APP}" "${CF_TCP_DOMAIN}" --random-port | tee "${TMP}/mysql"
cf set-env   "${SERVER_APP}" MYSQL_ROOT_PASSWORD "${MYSQL_PASS}"
cf set-env   "${SERVER_APP}" MYSQL_ROOT_HOST '%'
cf start     "${SERVER_APP}"

MYSQL_PORT="$(get_port mysql)"
wait_on_database "${MYSQL_PORT}" "${MYSQL_USER}" "${MYSQL_PASS}"

## --(2)-- Create and configure the mysql client sidecar for usb.

cf push "${SIDECAR_APP}" --no-start -o registry.suse.com/cap/cf-usb-sidecar-mysql:1.0.1

# Use a secret key that will be used by the USB to talk to your
# sidecar, and set the connection parameters for the mysql client
# sidecar so that it can talk to the mysql server from the previous
# step.
cf set-env "${SIDECAR_APP}" SIDECAR_API_KEY    "${SIDECAR_API_KEY}"
cf set-env "${SIDECAR_APP}" SERVICE_MYSQL_HOST "${CF_TCP_DOMAIN}"
cf set-env "${SIDECAR_APP}" SERVICE_MYSQL_PORT "${MYSQL_PORT}"
cf set-env "${SIDECAR_APP}" SERVICE_MYSQL_USER "${MYSQL_USER}"
cf set-env "${SIDECAR_APP}" SERVICE_MYSQL_PASS "${MYSQL_PASS}"
cf start   "${SIDECAR_APP}"

# --(3)-- Create a driver endpoint to the mysql sidecar (== service type)
# Note that the -c ":" is required as a workaround to a known issue
cf usb-create-driver-endpoint "${SERVICE_TYPE}" \
    "https://${SIDECAR_APP}.${CF_DOMAIN}" \
    "${SIDECAR_API_KEY}" \
    -c ":"

# --(4)-- Check that the service is available in the marketplace and use it

## Note: The commands without grep filtering are useful in case of
## failures, providing immediate information about the data which runs
## through and fails the filter.

cf marketplace
cf marketplace | grep "${SERVICE_TYPE}"

cf create-service "${SERVICE_TYPE}" default "${SERVICE_INSTANCE}"

cf services
cf services | grep "${SERVICE_INSTANCE}"

# -- If we want to, we can now create and push an app which uses the
#    service-instance as database, and verify that it works.

exit 0
