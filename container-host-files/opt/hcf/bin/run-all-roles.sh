#!/bin/bash
set -e

BINDIR=`readlink -f "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)/"`

. "${BINDIR}/common.sh"

set_colors
load_all_roles

setup_dir="${1}"

if [[ -z "${setup_dir}" ]] ; then
    echo "Usage: ${0} <DIR_WITH_ENV_FILES>" >&2
    exit 1
fi

# Start pre-flight roles
echo -e "${txtgrn}Starting pre-flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage pre-flight)
do
    if [[ "$(get_role_type ${role})" == "bosh" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh for stage pre-flight"
    fi
    dockerargs=$(get_role_docker_args $role)
    ${BINDIR}/run-role.sh "${setup_dir}" "$role" "$dockerargs"
done

# Start flight roles
echo -e "${txtgrn}Starting flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage flight)
do
    if [[ "$(get_role_type ${role})" == "bosh-task" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh-task for stage flight"
    fi
    dockerargs=$(get_role_docker_args $role)
    ${BINDIR}/run-role.sh "${setup_dir}" "$role" "$dockerargs"
done

# Start post-flight roles
echo -e "${txtgrn}Starting post-flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage post-flight)
do
    if [[ "$(get_role_type ${role})" == "bosh" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh for stage post-flight"
    fi
    dockerargs=$(get_role_docker_args $role)
    ${BINDIR}/run-role.sh "${setup_dir}" "$role" "$dockerargs"
done
