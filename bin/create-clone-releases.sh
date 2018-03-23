#!/usr/bin/env bash
set -o errexit

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

mkdir -p ${GIT_ROOT}/_work/LOG/ccr
for dir in ${FISSILE_RELEASE//,/ } ; do
    clone="${dir#${PWD}/}-clone"
    if ! test -d "${clone}" ; then
        continue
    fi
    release="$(basename "${dir}" -release)"
    echo
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ "${release}" @ "${clone#${GIT_ROOT}/}" ___
    echo
    unset RUBY_VERSION
    case "${release}" in
        *cf-mysql*) export RUBY_VERSION=2.3.1 ;;
    esac
    "${GIT_ROOT}/bin/create-release.sh" "${clone}" "${release}" \
        > >( tee "${GIT_ROOT}/_work/LOG/ccr/${release}" ) 2>&1
done
