#!/usr/bin/env bash
# set -x

if [ -z "$1" ]; then
    echo "usage: get-versions RELEASE"
    exit
fi

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

RELEASE=$1

# gem install csv2json yaml2json orderedhash
# brew install jq

CF_DEPLOYMENT=https://raw.githubusercontent.com/cloudfoundry/cf-deployment/v${RELEASE}/cf-deployment.yml

# Save, comms to update-releases
mkdir -p ${GIT_ROOT}/_work

curl $CF_DEPLOYMENT 2>/dev/null \
    > ${GIT_ROOT}/_work/deployment.yml

cat ${GIT_ROOT}/_work/deployment.yml \
    | perl -ne 's#.*/([^/]+-release)\?v=(.*)#$1: $2# && print' \
    | grep -v .-buildpack-release \
    | sed -e 's/: /,/' \
    > ${GIT_ROOT}/_work/release.csv

( echo name,version ; cat ${GIT_ROOT}/_work/release.csv ) \
    | csv2json \
    > ${GIT_ROOT}/_work/release.json

cat ${GIT_ROOT}/_work/release.csv
exit
