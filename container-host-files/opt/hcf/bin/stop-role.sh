#!/bin/bash
set -e

ROOT=`readlink -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../"`

. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

if [ $# -ne 1 ]
then
    echo 1>&2 "Usage: $(basename "$0") role"
    exit 1
else
    role_name="$1"
fi

# Stop the specified role
echo "Stopping ${role_name} ..."
kill_role "$role_name" || true

exit 0
