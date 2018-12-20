#!/usr/bin/env bash

# This installs extra tools for Jenkins slaves

zypper() {
    command zypper --non-interactive "$@"
}

if zypper --no-refresh products --installed-only | grep --silent SLES ; then
    product=SLE
else
    product=openSUSE_Leap
fi
# $releasever is 12.3 on SLE12SP3, but the repo is ...12_SP3; use the string instead
releasever="$(awk -F'"' '/^VERSION=/ { print $2 }' /etc/os-release | tr - _)"

if ! command -v jq ; then
    if ! zypper search --match-exact jq ; then
        repo="http://download.opensuse.org/repositories/Cloud:Platform:SUSE-Stemcell/${product}_${releasever}"
        zypper addrepo --check --priority 150 "${repo}" utilities
        zypper --gpg-auto-import-keys refresh utilities
    fi
    zypper install jq
fi
