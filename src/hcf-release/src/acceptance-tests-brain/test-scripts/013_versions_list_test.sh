#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}
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
    cf delete -f ${APP_NAME}
    login_cleanup
}
trap test_cleanup EXIT ERR

# Sample output:

# id   droplet hash                           created at
# 0    7340ba22-6cb6-43e5-8f36-a3896829af38   Fri Sep 16 18:46:26 UTC 2016
# 1    63e574ef-c3d5-4034-acf1-ac7b62dba7dd   Fri Sep 16 18:49:17 UTC 2016
# 2    06d3e1f0-f301-4dff-bafb-656302aea739   Fri Sep 16 18:49:53 UTC 2016
# 3    9bd57681-602e-4ce5-b7d5-ebd5c9bfbc5e   Fri Sep 16 18:50:48 UTC 2016
# 4    8e6ac666-0d42-4cd7-8b81-08c30b8349c5   Fri Sep 16 18:51:24 UTC 2016
# OK

# 123456789 123456789 123456789 123456789 123456789 123456789 123456789 12

# Get the droplet hash of the given version id
get_droplet_hash() {
    cf list-versions ${APP_NAME} | awk "/^${1} /"'{ print $2 }'
}
# Get the time stamp (as a number) of the given version id
get_timestamp() {
    date --date="$(cf list-versions ${APP_NAME} | awk "/^${1} /"'{ print substr($_, 45) }')" +%s
}

# push an app 5 times
for (( i = 0 ; i < 5 ; i ++ )) ; do
    cd ${SELFDIR}/../test-resources/${APP_DIR}
    cf push ${APP_NAME}
done

# Check that we have 5 versions
for (( i = 0 ; i < 5 ; i ++ )) ; do
    cf list-versions ${APP_NAME}
    droplet_hash="$(get_droplet_hash ${i})"
    printf "Got droplet hash %s for version %s\n" "${droplet_hash}" "${i}"
    test -n "${droplet_hash}"
done

# Check that all versions have a non-zero timestamp
for (( i = 0 ; i < 5 ; i ++ )) ; do
    timestamp="$(get_timestamp ${i})"
    printf "Got timestamp %s for version %s\n" "${timestamp}" "${i}"
    test "${timestamp}" -gt 0
done

# Check that all timestamps are incrementing
for (( i = 0 ; i < 4 ; i ++ )) ; do
    printf "Checking that timestamp for version %s is older than version %s\n" "${i}" "$((i + 1))"
    test $(get_timestamp ${i}) -lt $(get_timestamp $((${i} + 1)) )
done
