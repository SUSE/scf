#!/bin/bash
set -e

SELFDIR="$(readlink -f "$(cd "$(dirname "$0")" && pwd)")"
source "${SELFDIR}/common.sh"

load_all_roles

function ip_address {
    docker inspect --format '{{ .NetworkSettings.Networks.hcf.IPAddress }}' $1
}

function monit_status {
    curl -s -u monit_user:monit_password http://$(ip_address $1):2822/_status
}

function actual_processes_in_role {
    monit_status $1 | perl -ne "s/'//g; print if s/Process //"
}

for role in $(list_all_bosh_roles); do
    for actual in $(actual_processes_in_role $role); do
        for process in $(list_processes_for_role $role); do
            if [[ $actual == $process ]]; then continue 2; fi
        done
        echo "$role is missing: $actual"
    done
done

