#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
POL=${DIR}/../test-resources/policy.json
APP=${DIR}/../test-resources/php-mysql-master
APP_NAME=scale-test-app
SCALESERVICE=scale-test-service

# login
cf api --skip-ssl-validation ${CF_API}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${ORG}
cf target -o  ${ORG}

# create space
cf create-space ${SPACE}
cf target -s    ${SPACE}

# push an app
( cd ${APP}
  cf push ${APP_NAME}
)

# test autoscaler
cf create-service app-autoscaler default $SCALESERVICE
cf bind-service         ${APP_NAME} $SCALESERVICE
cf restage              ${APP_NAME}
cf autoscale set-policy ${APP_NAME} ${POL}

sleep 60
instances=$(cf apps|grep ${APP_NAME}|awk '{print $3}'|cut -f 1 -d \/)

cf unbind-service ${APP_NAME} $SCALESERVICE

cf delete-service -f $SCALESERVICE

cf delete -f ${APP_NAME}

# delete space
cf delete-space -f ${SPACE}

# delete org
cf delete-org -f ${ORG}

[ -z "$instances" ] && instances=0

if [ ! $instances -gt 1 ];
then
  echo "ERROR autoscaling app"
  echo "Autoscaling failed, only $instances instance(s)"
  exit 1
fi
