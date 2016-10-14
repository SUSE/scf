#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
APP_NAME=node-env

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create org and space
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# push an app
cd ${DIR}/../test-resources/${APP_NAME}
cf push ${APP_NAME}

# verify it is the unmodified version
curl ${APP_NAME}.${CF_DOMAIN} | grep "HPE Helion Stackato"

# get version of the first instance
version=$(cf list-versions ${APP_NAME} | awk '/^0 / {print $2}')

# push the app again, slightly modified
cd ${DIR}/../test-resources/${APP_NAME}
sed -i 's/HPE Helion Stackato/Test Brain/' index.html
cf push ${APP_NAME}

# verify it is the modified version
curl ${APP_NAME}.${CF_DOMAIN} | grep "Test Brain"

# rollback to unmodified version
cf rollback ${APP_NAME} ${version}

# verify it is the unmodified version again
curl ${APP_NAME}.${CF_DOMAIN} | grep "HPE Helion Stackato"

# cleanup
cf delete -f ${APP_NAME}
cf delete-space -f ${CF_SPACE}
cf delete-org -f ${CF_ORG}
