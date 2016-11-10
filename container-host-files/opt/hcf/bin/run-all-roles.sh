#!/bin/bash
set -e

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" start

# Check for the filter helper file created for us by 'make run'.
# If it is missing create it ourselves
ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../../../"`
CLEAN=""
if test ! -f $ROOT/vagrant.json ; then
    ( cd $ROOT ; make/generate vagrant )
    CLEAN="${CLEAN} $ROOT/vagrant.json"
fi

BINDIR=`readlink -f "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)/"`

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" setup::start

. "${BINDIR}/common.sh"

set_colors
load_all_roles

setup_dir="${1}"

if [[ -z "${setup_dir}" ]] ; then
    echo "Usage: ${0} <DIR_WITH_ENV_FILES>" >&2
    exit 1
fi

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" setup::done

# Start pre-flight roles
echo -e "${txtgrn}Starting pre-flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage pre-flight)
do
    if [[ "$(get_role_type ${role})" == "bosh" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh for stage pre-flight"
    fi
    stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" role::${role}::start
    . ${BINDIR}/run-role.sh "${setup_dir}" "$role"
    stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" role::${role}::done
done

# Start flight roles
echo -e "${txtgrn}Starting flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage flight)
do
    if [[ "$(get_role_type ${role})" == "bosh-task" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh-task for stage flight"
    fi
    stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" role::${role}::start
    . ${BINDIR}/run-role.sh "${setup_dir}" "$role"
    stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" role::${role}::done
done

# Start post-flight roles
echo -e "${txtgrn}Starting post-flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage post-flight)
do
    if [[ "$(get_role_type ${role})" == "bosh" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh for stage post-flight"
    fi
    stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" role::${role}::start
    . ${BINDIR}/run-role.sh "${setup_dir}" "$role"
    stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" role::${role}::done
done

rm -f $CLEAN

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" done
