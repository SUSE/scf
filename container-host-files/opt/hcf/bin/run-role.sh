#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.
set -e

if [ $# -ne 2 ]
then
    echo 1>&2 "Usage: $(basename "$0") /path/to/setup/dir role"
    exit 1
else
    setup_dir="$1"
    role_name="$2"
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

# Vagrant has .runrc 2 level up in the mounted hierarchy.
# Terraform has no such copied to its VM, thus requires defaults.

if [ -f "${ROOT}/../bin/.runrc" ] ; then
    . "${ROOT}/../bin/.runrc"
fi

HCF_RUN_STORE="${HCF_RUN_STORE:-$HOME/.run/store}"
HCF_RUN_LOG_DIRECTORY="${HCF_RUN_LOG_DIRECTORY:-$HOME/.run/log}"

store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY

# (Re)start the specified role
handle_restart "$role_name" \
    "${setup_dir}/dev-settings.env" \
    "${setup_dir}/dev-certs.env" \
    || true

exit 0
