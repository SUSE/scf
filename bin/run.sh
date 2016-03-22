#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

set_colors
load_all_roles

# Start pre-flight roles
echo -e "${txtgrn}Starting pre-flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage pre-flight)
do
    if [[ "$(get_role_type ${role})" == "bosh" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh for stage pre-flight"
    fi
    ${ROOT}/container-host-files/opt/hcf/bin/run-role.sh "${ROOT}/bin" "$role"
done

# Start flight roles
echo -e "${txtgrn}Starting flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage flight)
do
    if [[ "$(get_role_type ${role})" == "bosh-task" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh-task for stage flight"
    fi
    ${ROOT}/container-host-files/opt/hcf/bin/run-role.sh "${ROOT}/bin" "$role"
done

# Start post-flight roles
echo -e "${txtgrn}Starting post-flight roles...${txtrst}"
for role in $(list_roles_by_flight_stage post-flight)
do
    if [[ "$(get_role_type ${role})" == "bosh" ]]
    then
        echo "${bldred}Role ${role} has invalid type bosh for stage post-flight"
    fi
    ${ROOT}/container-host-files/opt/hcf/bin/run-role.sh "${ROOT}/bin" "$role"
done

# Show targeting and other information.

. "${ROOT}/bin/dev-settings.env"

echo -e "
Your Helion Cloud Foundry endpoint is: ${bldcyn}https://api.${DOMAIN}${txtrst}
Run the following command to target it: ${bldcyn}cf api --skip-ssl-validation https://api.${DOMAIN}${txtrst}
The Universal Service Broker endpoint is: ${bldcyn}https://usb.${DOMAIN}${txtrst}
Your administrative credentials are:
  Username: ${bldcyn}${CLUSTER_ADMIN_USERNAME}${txtrst}
  Password: ${bldcyn}${CLUSTER_ADMIN_PASSWORD}${txtrst}

It may take some time for everything to come online.
You can use ${bldcyn}hcf-status${txtrst} or ${bldcyn}hcf-status-watch${txtrst} to check if everything is up and running.
"

exit 0
