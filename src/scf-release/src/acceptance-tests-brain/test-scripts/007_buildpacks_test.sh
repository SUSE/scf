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
TMP=$(mktemp -dt 017_buildpacks.XXXXXX)
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSPECTOR_BUILDPACK_DIR=${SELFDIR}/../test-resources/buildpack_inspector_buildpack

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    login_cleanup
    set +o errexit

    cf delete-buildpack -f buildpack_inspector_buildpack

    rm -rf "${TMP}"

    set -o errexit
}
trap test_cleanup EXIT ERR

# Sample output:
##
# Getting buildpacks...
#
# buildpack              position   enabled   locked   filename
# staticfile_buildpack   1          true      false    staticfile_buildpack-v1.3.13.zip
# java_buildpack         2          true      false    java-buildpack-v3.10.zip
# ruby_buildpack         3          true      false    ruby_buildpack-v1.6.28.zip
# nodejs_buildpack       4          true      false    nodejs_buildpack-v1.5.23.zip
# go_buildpack           5          true      false
# python_buildpack       6          true      false
# php_buildpack          7          true      false    php_buildpack-v4.3.22.zip
# binary_buildpack       8          true      false    binary_buildpack-v1.0.5.zip
##
# 123456789.123456789.12 123456789. 123456789 12345678 123456789.123456789.123456789.123456789.1

list_buildpacks() {
    cf buildpacks > ${TMP}/buildpacks
}

get_buildpacks() {
    cat ${TMP}/buildpacks
}

# Get the buildpack name for the given position
get_name() {
    get_buildpacks | awk "/ ${1} /"'{ print $1 }'
}

get_filename() {
    get_buildpacks | awk "/ ${1} /"'{ print $5 }'
}

list_buildpacks
get_buildpacks

# Check that the (nine) standard buildpacks are present
for pack in \
    binary \
    dotnet-core \
    go \
    java \
    nodejs \
    php \
    python \
    ruby \
    staticfile \
    ${NULL}
do
    get_buildpacks | grep ^${pack}_buildpack
done

lines=$(get_buildpacks | wc -l)
packs=$(expr $lines - 3)

# Check that all buildpacks have a name and a filename
for (( i = 1 ; i <= $packs ; i ++ )) ; do
    name="$(get_name ${i})"
    printf "Got name %s for position %s\n" "${name}" "${i}"
    test -n "${name}"

    # Note: A missing file indicates that the upload of the buildpack
    # archive failed in some way. Look in the cloud_controller_ng.log
    # for anomalies. The anomalies which triggered the writing of this
    # test were Mysql errors (transient loss of connection) which
    # prevented the registration of the uploaded archive in the CC-DB.

    filename="$(get_filename ${i})"
    printf "Got filename %s for position %s\n" "${filename}" "${i}"
    test -n "${filename}"
done

# Check that all buildpacks are uncached variants.
# In order to do so a special inspector buildpack is added which inspects all
# other buildpacks at staging time for cached dependencies.
# An empty app is then pushed which won't be accepted by any of the regular
# buildpacks. Only the inspector buildpack will accept the app if the "uncached"
# check passes.

# Add buildpack
inspector_filename=${TMP}/buildpack_inspector_buildpack_v0.0.1.zip
(cd ${INSPECTOR_BUILDPACK_DIR}; zip -r ${inspector_filename} *)
cf create-buildpack buildpack_inspector_buildpack ${inspector_filename} 1

# Deploy app
dummy_app_dir=${TMP}/dummy-app
mkdir ${dummy_app_dir}
cd ${dummy_app_dir}
touch foo
cf push dummy-app -c /bin/bash -u none
