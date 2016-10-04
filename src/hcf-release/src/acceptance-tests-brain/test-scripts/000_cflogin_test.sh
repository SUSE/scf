#!/bin/bash

set -o errexit
set -o xtrace

# login
cf api --skip-ssl-validation ${CF_API}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${ORG}
cf target -o ${ORG}

# create space
cf create-space ${SPACE}
cf target -s ${SPACE}

# delete space
cf delete-space -f ${SPACE}

# delete org
cf delete-org -f ${ORG}

