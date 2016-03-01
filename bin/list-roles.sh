#!/bin/bash
set -e

ROOT=`readlink -f "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/../"`

. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

load_all_roles

for r in $(list_all_bosh_roles | sort)
do
    echo -e "\t$r"
done

exit 0
