#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
APP=${DIR}/../test-resources/node-env
APP_NAME=tcp-route-node-env
DOMAIN=$(echo $CF_API | sed -e 's/^[^.]*\.//')
STATUS=0

# login
cf api --skip-ssl-validation ${CF_API}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${ORG}
cf target -o  ${ORG}

# create space
cf create-space ${SPACE}
cf target -s    ${SPACE}

(   cd ${APP}
    cf push  ${APP_NAME}
)

# set up tcp routing
cf create-shared-domain  tcp-test.${DOMAIN} --router-group default-tcp
cf update-quota default --reserved-route-ports -1

cf map-route ${APP_NAME} tcp-test.${DOMAIN} --random-port | tee /tmp/log

# retrieve the assigned random port
port=$(cat /tmp/log | \
    grep Route | \
    grep 'has been created' | \
    awk '{print $2}' | \
    cut -f 2 -d ':')
rm /tmp/log

if [ -z "$port" ]; then
  echo "ERROR: Could not determine the assigned random port number"
  echo "ERROR: Mapping route to random port failed"
  STATUS=1
else
  #check that the aplication works
  curl tcp-test.${DOMAIN}:$port

  # unmap tcp route
  cf unmap-route ${APP_NAME} tcp-test.${DOMAIN} --port $port
fi

# delete shared domain
cf delete-shared-domain -f tcp-test.${DOMAIN}

# delete app
cf delete -f ${APP_NAME}

# delete space
cf delete-space -f ${SPACE}

# delete org
cf delete-org -f ${ORG}

# report
exit $STATUS
