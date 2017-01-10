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

# Set an overall 5 minute deadline if none was supplied by the test
# brain.
DEADLINE=${TESTBRAIN_DEADLINE:-$(expr $(date +%s) + ${TESTBRAIN_TIMEOUT:-300})}

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

# Check for successful scaling until we got it or we have only about
# 30 seconds left on the deadline. In the latter case stop, fail and
# run the cleanup in the remaining time. Note, if the setup left us
# with less than 30 seconds anyway we fail directly instead of
# entering the loop.
trials=1
instances=0
while [ $(expr $DEADLINE - $(date +%s)) -gt 30 ]
do
    echo Check $trials
    instances=$(cf apps|grep ${APP_NAME}|awk '{print $3}'|cut -f 1 -d /)
    [ -z "${instances}" ] && instances=0
    if [ ${instances} -gt 1 ]
    then
	echo Check $trials OK
	break
    fi
    trials=$(expr $trials + 1)
    sleep 10
done

if [ ${instances} -le 1 ]
then
  echo "ERROR autoscaling app"
  echo "Autoscaling failed, only ${instances} instance(s), expected at least 2"
  exit 1
fi
