#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

## # # ## ### Login & standard entity setup/cleanup ### ## # #
# target & login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

## # # ## ### Test-specific configuration ### ## # #
## Remove and extend as needed

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SGJ=${SELFDIR}/../test-resources/secgroup.json

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    # unbind security groups from containers that stage and run apps
    cf unbind-staging-security-group internal-services-workaround
    cf unbind-running-security-group internal-services-workaround

    cf delete-security-group -f internal-services-workaround

    set -o errexit
}
trap test_cleanup EXIT ERR

cf create-security-group internal-services-workaround ${SGJ}

# bind new security group to containers that run and stage apps
cf bind-running-security-group internal-services-workaround
cf bind-staging-security-group internal-services-workaround
