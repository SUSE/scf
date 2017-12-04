#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

## # # ## ### Login & standard entity setup/cleanup ### ## # #

# target, login, create work org and space
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

## # # ## ### Test-specific configuration ### ## # #

# Location of the test script. All other assets will be found relative
# to this.
TMP=$(mktemp -dt 017_buildpacks.XXXXXX)

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    rm -rf "${TMP}"

    set -o errexit
}
trap test_cleanup EXIT ERR

# Sample output:
##
# Getting buildpacks...
#
# buildpack              position   enabled   locked   filename
# staticfile_buildpack   1          true      false    staticfile_buildpack-cached-v1.3.13.zip
# java_buildpack         2          true      false    java-buildpack-v3.10.zip
# ruby_buildpack         3          true      false    ruby_buildpack-cached-v1.6.28.zip
# nodejs_buildpack       4          true      false    nodejs_buildpack-cached-v1.5.23.zip
# go_buildpack           5          true      false
# python_buildpack       6          true      false
# php_buildpack          7          true      false    php_buildpack-cached-v4.3.22.zip
# binary_buildpack       8          true      false    binary_buildpack-cached-v1.0.5.zip
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
