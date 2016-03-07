#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

set_colors
load_all_roles

bosh_roles=($(list_all_bosh_roles))

# Start the bosh roles
for bosh_role in "${bosh_roles[@]}"
do
    ${ROOT}/container-host-files/opt/hcf/bin/run-role.sh "${ROOT}/bin" "$bosh_role"
done

docker_roles=($(list_all_docker_roles))

# Start the docker roles
for docker_role in "${docker_roles[@]}"
do
    ${ROOT}/container-host-files/opt/hcf/bin/run-role.sh "${ROOT}/bin" "$docker_role"
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
