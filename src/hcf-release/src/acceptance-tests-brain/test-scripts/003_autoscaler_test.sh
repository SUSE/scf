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
POL=${SELFDIR}/../test-resources/policy.json
APP=${SELFDIR}/../test-resources/php-mysql
APP_NAME=scale-test-app-$(random_suffix)
SCALESERVICE=scale-test-service

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf unbind-service ${APP_NAME} ${SCALESERVICE}
    cf delete-service -f ${SCALESERVICE}
    cf delete -f ${APP_NAME}

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# push an app for the autscaler to operate on
cd ${APP}
cf push ${APP_NAME}

# test autoscaler
cf create-service app-autoscaler default ${SCALESERVICE}
cf bind-service ${APP_NAME} ${SCALESERVICE}
cf restage ${APP_NAME}
cf autoscale set-policy ${APP_NAME} ${POL}

trials=30 ;# * 10 seconds/round = 300 seconds = 5 minutes
while [ $trials -gt 0 ]
do
    echo Count $trials
    sleep 10
    instances=$(cf apps|grep ${APP_NAME}|awk '{print $3}'|cut -f 1 -d /)
    [ -z "${instances}" ] && instances=0
    if [ ${instances} -gt 1 ]
    then
	echo Count $trials OK
	break
    fi
    trials=$(expr $trials - 1)
done

if [ ${instances} -le 1 ]
then
  echo "ERROR autoscaling app"
  echo "Autoscaling failed, only ${instances} instance(s), expected at least 2"
  exit 1
fi
