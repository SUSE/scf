#!/bin/bash
set -e

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

mkdir -p LOG/dr
for clonedir in $(find . -type d -name '*-clone')
do
    release=$(echo $(basename ${clonedir}) | sed -e 's/-clone//' -e 's/-release//')
    reldir=$(echo ${clonedir} | sed -e 's/-clone//')

    echo
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ C $clonedir ___
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ R $reldir ___
    echo
    (
	FISSILE_RELEASE='' fissile diff --release ${reldir},${clonedir}
    ) 2>&1 | tee LOG/dr/${release}
done
