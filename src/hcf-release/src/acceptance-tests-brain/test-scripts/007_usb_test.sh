#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TMP=$(mktemp -dt 007_usb.XXXXXX)

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
    --no-start | tee ${TMP}/log
cf set-env ${HSM_SERVICE_INSTANCE} SIDECAR_API_KEY string_empty
cf restart ${HSM_SERVICE_INSTANCE}

# get the random port assigned
port=$(awk "/Binding .* to ${HSM_SERVICE_INSTANCE}/ {print \$2}" < ${TMP}/log | cut -f 2 -d ':')

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
yes | cf usb delete-driver-endpoint de${HSM_SERVICE_INSTANCE}

#delete hsm_passtrough
cf delete -f ${HSM_SERVICE_INSTANCE}

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}

rm -rf ${TMP}
