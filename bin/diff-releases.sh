#!/usr/bin/env bash
set -o errexit

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

mkdir -p ${GIT_ROOT}/_work/LOG/dr
for reldir in ${FISSILE_RELEASE//,/ } ; do
    reldir="${reldir#${PWD}/}"
    clonedir="${reldir}-clone"
    if ! test -d "${clonedir}" ; then
        continue
    fi
    release="$(basename "${reldir}" -release)"

    echo
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ C $clonedir ___
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ R $reldir ___
    echo
    FISSILE_RELEASE='' fissile diff --release "${reldir},${clonedir}" \
        > >(tee "${GIT_ROOT}/_work/LOG/dr/${release}") 2>&1
    if ! test -s "${GIT_ROOT}/_work/LOG/dr/${release}" ; then
        rm "${GIT_ROOT}/_work/LOG/dr/${release}"
    fi
done
