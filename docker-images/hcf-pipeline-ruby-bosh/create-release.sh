#!/bin/bash

# This script is run to create a bosh release
# A wrapper is required to handle UID creation
# Usage:
#  $0 <uid> <gid> <bosh cache directory> <bosh create-release args>

set -o errexit -o nounset

if test "$(id -u)" != 0 ; then
    printf "%bERROR%b: wrong user %s\n" "\033[0;1;31m" "\033[0m" "$(id -u)" >&2
    exit 1
fi

uid="${1}"
gid="${2}"
bosh_cache="${3}"
shift 3

env | grep -i proxy | sort | sed -e 's/^/PROXY SETUP: /'

if ! grep --quiet -E ":${gid}:\$" /etc/group ; then
    addgroup --gid "${gid}" docker-group
fi
group_name="$(awk -F : "/:${gid}:\$/ { print \$1 }" /etc/group)"
useradd --gid "${gid}" --groups rvm --create-home --uid "${uid}" docker-user
mkdir ~docker-user/.bosh
chown "docker-user:${group_name}" ~docker-user/.bosh
ln -s "${bosh_cache}" ~docker-user/.bosh/cache
exec sudo -E --user=docker-user --group="${group_name}" --set-home -- \
    bash --login -c "bosh create release $*"
