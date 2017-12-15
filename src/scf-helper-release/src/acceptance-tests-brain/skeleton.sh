#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #
## Remove CF_ variables not used by the test.

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)
CF_TCP_DOMAIN=${CF_TCP_DOMAIN:-tcp-$(random_suffix).${CF_DOMAIN}}

## # # ## ### Login & standard entity setup/cleanup ### ## # #
## Remove operations not relevant to the test

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
## Remove and extend as needed

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## # # ## ### Test-specific code ### ## # #
## For custom cleanup retrap the signals EXIT & ERR to run a custom
## function, and chain to login_cleanup inside. Remove if not needed.

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    # ... custom cleanup

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# ...
