#!/bin/bash

set -o errexit
set -o xtrace

# login
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}

