#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
APP=${DIR}/../test-resources/node-env
APP_NAME=tcp-route-node-env
STATUS=0
TMP=$(mktemp -dt 006_tcprouting.XXXXXX)

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

(   cd ${APP}
    cf push ${APP_NAME}
)

# set up tcp routing
cf create-shared-domain  tcp-test.${CF_DOMAIN} --router-group default-tcp
cf update-quota default --reserved-route-ports -1

cf map-route ${APP_NAME} tcp-test.${CF_DOMAIN} --random-port | tee ${TMP}/log

# retrieve the assigned random port
port=$(awk '/Route .* has been created/ {print $2}' < ${TMP}/log | cut -f 2 -d ':')

if [ -z "${port}" ]; then
  echo "ERROR: Could not determine the assigned random port number"
  echo "ERROR: Mapping route to random port failed"
  STATUS=1
else
  #check that the aplication works
  curl tcp-test.${CF_DOMAIN}:${port}

  # unmap tcp route
  cf unmap-route ${APP_NAME} tcp-test.${CF_DOMAIN} --port ${port}
fi

# delete shared domain
cf delete-shared-domain -f tcp-test.${CF_DOMAIN}

# delete app
cf delete -f ${APP_NAME}

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}

rm -rf ${TMP}

# report
exit ${STATUS}
