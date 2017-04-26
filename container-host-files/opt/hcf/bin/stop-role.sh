#!/bin/bash
set -e

if [ $# -ne 1 ]
then
    echo 1>&2 "Usage: $(basename "$0") role"
    exit 1
else
    role_name="$1"
fi

# Vagrant
# SELF    = PWD/container-host-files/opt/hcf/bin/list-roles.sh
# SELFDIR = PWD/container-host-files/opt/hcf/bin

SELFDIR="$(readlink -f "$(cd "$(dirname "$0")" && pwd)")"

. "${SELFDIR}/common.sh"

# Stop the specified role
echo "Stopping ${role_name} ..."
kill_role "$role_name" || true

exit 0
