#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#configuration
DOCKERAPP=docker-test-app

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# Push a docker app
cf enable-feature-flag diego_docker
cf push ${DOCKERAPP} -o viovanov/node-env-tiny

# delete app
cf delete -f ${DOCKERAPP}

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}
