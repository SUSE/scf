#!/bin/bash
set -e

# Terraform, in HOS/MPC VM, hcf-infra container support as copied
# SELF    = /opt/hcf/bin/list-roles.sh
# SELFDIR = /opt/hcf/bin
# ROOT    = /            (3x .. from SELFDIR)
#
# Vagrant
# SELF    = PWD/container-host-files/opt/hcf/bin/list-roles.sh
# SELFDIR = PWD/container-host-files/opt/hcf/bin
# ROOT    = PWD/container-host-files             (3x .. from SELFDIR)

SELFDIR="$(readlink -f "$(cd "$(dirname "$0")" && pwd)")"
ROOT="$(readlink -f "$SELFDIR/../../../")"

. "${ROOT}/opt/hcf/bin/common.sh"

load_all_roles && list_all_docker_roles
exit 0
