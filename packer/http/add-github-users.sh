#!/usr/bin/env bash

# Allow GitHub users to access this machine via SSH
# Requires the following environment variables:
# - GITHUB_ACCESS_TOKEN
# - GITHUB_TEAM_ID

set -o errexit -o nounset

curl --silent -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" "https://api.github.com/teams/${GITHUB_TEAM_ID}/members" \
    | jq -r '.[].login' \
    | while read id ; do
        curl --silent "https://github.com/${id}.keys" | sed "s#\$# ${id}@github#" | tee -a ~ec2-user/.ssh/authorized_keys
    done
