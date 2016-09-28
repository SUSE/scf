#!/bin/bash

set -ex

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cwd=`pwd`

# login
cf api --skip-ssl-validation ${CF_API}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${ORG}
cf target -o ${ORG}

# create space
cf create-space ${SPACE}
cf target -s ${SPACE}

# push an app
cd ${DIR}/../test-resources
tar xzf node-env.tgz
cd node-env
cf push node-env

# delete the app
cf delete -f node-env

# delete space
cf delete-space -f ${SPACE}

# delete org
cf delete-org -f ${ORG}

cd $cwd
