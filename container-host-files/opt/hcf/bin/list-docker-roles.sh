#!/bin/bash
set -e

# Vagrant
# SELF    = PWD/container-host-files/opt/hcf/bin/list-docker-roles.sh
# SELFDIR = PWD/container-host-files/opt/hcf/bin

SELFDIR="$(readlink -f "$(cd "$(dirname "$0")" && pwd)")"

. "${SELFDIR}/common.sh"

load_all_roles && list_all_docker_roles
exit 0
