#!/bin/bash
set -e

ROOT=`readlink -f "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/../"`

. "${ROOT}/bin/.fissilerc"
. "${ROOT}/bin/.runrc"
. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

for r in $(get_role_images  | to_roles | sort)
do
    echo -e "\t$r"
done

exit 0
