#!/bin/bash

# This script is run to create a bosh release
# A wrapper is required to handle UID creation
# Usage:
#  $0 <uid> <gid> <bosh cache directory> <bosh create-release args>

set -o errexit -o nounset

if test "$(id -u)" != 0 ; then
    printf "%bERROR%b: wrong user %s; this should be run as root (in the container)\n" \
        "\033[0;1;31m" "\033[0m" "$(id -u)" >&2
    exit 1
fi

uid="${1}"
gid="${2}"
bosh_cache="${3}"
shift 3

env | grep -i proxy | sort | sed -e 's/^/PROXY SETUP: /'

# Add a user in the given group, so we can run `bosh create release` as that user.
# All this stuff is to make sure that the correct user (the one that ran
# `make releases` for HCF) will own the files created, instead of root.
if ! getent group "${gid}" >/dev/null ; then
    addgroup --gid "${gid}" docker-group
fi
group=$(getent group "${gid}" | cut -d: -f1)
if ! getent passwd "${uid}" >/dev/null ; then
    useradd --gid "${gid}" --create-home --uid "${uid}" docker-user
fi
user=$(getent passwd "${uid}" | cut -d: -f1)
home=$(getent passwd "${uid}" | cut -d: -f6)
mkdir "${home}/.bosh"
chown "${user}:${group}" "${home}/.bosh"
ln -s "${bosh_cache}" "${home}/.bosh/cache"
exec sudo -E "--user=${user}" "--group=${group}" --set-home -- \
    bash --login -c "bosh create release $*"
