#!/bin/sh

set -e

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

RELEASE=$1

VERSION_INFO=$($GIT_ROOT/bin/get-cf-versions.sh $RELEASE)

CF_RELEASE=$(echo $VERSION_INFO | jq -r .[\"cf-release-commit-sha\"])
ETCD_RELEASE=v$(echo $VERSION_INFO | jq -r .[\"etcd-release-version\"])
GARDEN_LINUX_RELEASE=v$(echo $VERSION_INFO | jq -r .[\"garden-linux-release-version\"])
DIEGO_RELEASE=$(echo $VERSION_INFO | jq -r .[\"diego-release-commit-sha\"])

update_submodule () {
	RELEASE_NAME=$1
	COMMIT_ID=$2
	cd $GIT_ROOT
	git clone src/$RELEASE_NAME src/$RELEASE_NAME-clone --recursive
	cd src/$RELEASE_NAME-clone
	git fetch --all
	git checkout $COMMIT_ID
	git submodule update --init --recursive
}

update_submodule cf-release $CF_RELEASE
update_submodule diego-release $DIEGO_RELEASE
update_submodule etcd-release $ETCD_RELEASE
update_submodule garden-linux-release $GARDEN_LINUX_RELEASE
