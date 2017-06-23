#!/usr/bin/env bash
set -e

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

mkdir -p LOG/ccr
for clone in $(find . -type d -name '*-clone')
do
    release=$(echo $(basename $clone) | sed -e 's/-clone//' -e 's/-release//')

    echo
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ $release @ $clone ___
    echo
    (
	${GIT_ROOT}/bin/create-release.sh $clone $release
    ) 2>&1 | tee LOG/ccr/${release}
done
