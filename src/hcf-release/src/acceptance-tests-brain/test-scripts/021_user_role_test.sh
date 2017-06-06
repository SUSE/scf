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
    cf delete-user test_user -f   
 
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

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

cf create-user test_user test_password

cf set-org-role test_user ${CF_ORG} OrgAuditor

cf auth test_user test_password

cf target -o ${CF_ORG}

trap '' EXIT ERR
set +o errexit

cf create-space test_space

if [ $? -eq 0 ]; then
 echo "FAIL"
 exit 1
fi

trap test_cleanup EXIT ERR
set -o errexit

cf auth ${CF_USERNAME} ${CF_PASSWORD}

cf target -o ${CF_ORG} -s ${CF_SPACE}

cf unset-org-role test_user ${CF_ORG} OrgAuditor

