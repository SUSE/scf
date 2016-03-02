#!/bin/bash
set -e

if [ $# -ne 1 ]
then
    echo 1>&2 "Usage: $(basename "$0") role"
    exit 1
else
    role_name="$1"
fi

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

# Stop the specified role
echo "Stopping ${role_name} ..."
kill_role "$role_name" || true

exit 0
