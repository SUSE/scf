#!/bin/bash

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
APP_DIR=node-env
APP_NAME=${APP_DIR}-$(random_suffix)

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create org and space
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# push an app
cd ${DIR}/../test-resources/${APP_DIR}
cf push ${APP_NAME}

# verify it is the unmodified version
curl ${APP_NAME}.${CF_DOMAIN} | grep "HPE Helion Stackato"

# get version of the first instance
version=$(cf list-versions ${APP_NAME} | awk '/^0 / {print $2}')

# push the app again, slightly modified
cd ${DIR}/../test-resources/${APP_DIR}
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
