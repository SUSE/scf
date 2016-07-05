#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.
set -e

if [ $# -lt 2 ]; then
    echo 1>&2 "Usage: $(basename "$0") <DIR_WITH_ENV_FILES> <ROLE_NAME> ?<EXTRA-DOCKER> ...?"
    exit 1
fi

setup_dir="$1"
role_name="$2"
shift 2

if [ ! -d "$setup_dir" ]; then
    echo 1>&2 "Config directory does not exist"
    exit 1
fi

# Terraform, in HOS/MPC VM, hcf-infra container support as copied
# SELF    = /opt/hcf/bin/list-roles.sh
# SELFDIR = /opt/hcf/bin
#
# Vagrant
# SELF    = PWD/container-host-files/opt/hcf/bin/list-roles.sh
# SELFDIR = PWD/container-host-files/opt/hcf/bin

SELFDIR="$(readlink -f "$(cd "$(dirname "$0")" && pwd)")"

. "${SELFDIR}/common.sh"

HCF_RUN_STORE="${HCF_RUN_STORE:-$HOME/.run/store}"
HCF_RUN_LOG_DIRECTORY="${HCF_RUN_LOG_DIRECTORY:-$HOME/.run/log}"

store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY

load_all_roles
# (Re)start the specified role
handle_restart "$role_name" "${setup_dir}" "$@"
