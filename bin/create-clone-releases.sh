#!/usr/bin/env bash
set -e

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

mkdir -p ${GIT_ROOT}/_work/LOG/ccr
for clone in $(find . -type d -name '*-clone')
do
    release=$(echo $(basename $clone) | sed -e 's/-clone//' -e 's/-release//')

    echo
    echo ___ ___ ___ ___ ___ ___ ___ ___ ___ $release @ $clone ___
    echo
    (
	case $release in
	    *cf-mysql*)
		RUBY_VERSION=2.3.1 ${GIT_ROOT}/bin/create-release.sh $clone $release
		;;
	    *)
		${GIT_ROOT}/bin/create-release.sh $clone $release
		;;
	esac
    ) 2>&1 | tee ${GIT_ROOT}/_work/LOG/ccr/${release}
done
