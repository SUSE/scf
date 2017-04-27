#!/bin/bash
set -x

if [ -z "$1" ]; then
    echo "usage: get-versions RELEASE"
    exit
fi

RELEASE=$1

# gem install csv2json yaml2json orderedhash
# brew install jq

CF_RELEASE=https://raw.githubusercontent.com/cloudfoundry/cf-release/master/releases/cf-$RELEASE.yml
COMMIT_HASH=$(curl $CF_RELEASE 2>/dev/null | yaml2json | jq '"X"+.commit_hash')

COMPAT=https://raw.githubusercontent.com/cloudfoundry/diego-cf-compatibility/master/compatibility-v9.csv
RELEASE_INFO=$(curl $COMPAT 2>/dev/null | perl -pe '$. == 1 or s/,/,X/g' | csv2json | jq -c "map( select(.[\"cf-release-commit-sha\"] | contains($COMMIT_HASH)))|.[-1]")

echo $RELEASE_INFO | jq . | perl -pe 's/"X/"/'
