#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

"${ROOT}/container-host-files/opt/hcf/bin/run-all-roles.sh" "${ROOT}/bin/settings"

. "${ROOT}/container-host-files/opt/hcf/bin/common.sh"

set_colors

# Show targeting and other information.

. "${ROOT}/bin/settings/settings.env"

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
