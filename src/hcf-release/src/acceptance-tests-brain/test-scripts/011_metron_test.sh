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

# test if there are logs
cf logs ${APP_NAME} --recent | grep -i Downloading

# cleanup
cf delete -f ${APP_NAME}
cf delete-space -f ${CF_SPACE}
cf delete-org -f ${CF_ORG}
