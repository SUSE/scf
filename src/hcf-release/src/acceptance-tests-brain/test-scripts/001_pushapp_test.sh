#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
APP=${DIR}/../test-resources/node-env

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# push an app
(   cd ${APP}
    cf push node-env
)

# delete the app
cf delete -f node-env

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}

