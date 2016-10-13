#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HSM_SERVICE_INSTANCE=hsm-service

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# allow tcp routing
cf create-shared-domain usb-test.${CF_DOMAIN} --router-group default-tcp
cf update-quota default --reserved-route-ports -1

# run hsm passthrough docker
cf push ${HSM_SERVICE_INSTANCE} \
    -o docker-registry.helion.space:443/rohcf/sidecar-acctests:latest \
    -d usb-test.${CF_DOMAIN} --random-route \
    --no-start
cf set-env ${HSM_SERVICE_INSTANCE} SIDECAR_API_KEY string_empty
cf restart ${HSM_SERVICE_INSTANCE} | tee /tmp/log

# get the random port assigned
port=$(cat /tmp/log | \
    grep Binding | \
    grep ${HSM_SERVICE_INSTANCE} | \
    awk '{print $2}' | \
    cut -f 2 -d ":")
rm /tmp/log

# add service
cf usb create-driver-endpoint de${HSM_SERVICE_INSTANCE} \
    https://usb-test.${CF_DOMAIN}:${port} string_empty \
    -k -c '{"display_name":"hsm_passtrough"}'

# push an app
cd ${DIR}/../assets/php-mysql-master
cf push ${APP_NAME}

# create & bind service
cf create-service de${HSM_SERVICE_INSTANCE} default srv${HSM_SERVICE_INSTANCE} \
    -c '{"display":"hsm_passtrough_acctests_service"}'
cf bind-service ${APP_NAME} srv${HSM_SERVICE_INSTANCE}

# restage app
cf restage ${APP_NAME}

# unbind service
cf unbind-service ${APP_NAME} srv${HSM_SERVICE_INSTANCE}

# delete app
cf delete -f ${APP_NAME}

# delete the service
cf delete-service -f srv${HSM_SERVICE_INSTANCE}

#delete driver endpoint
echo -e "y\n" | cf usb delete-driver-endpoint de${HSM_SERVICE_INSTANCE}

#delete hsm_passtrough
cf delete -f ${HSM_SERVICE_INSTANCE}

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}

