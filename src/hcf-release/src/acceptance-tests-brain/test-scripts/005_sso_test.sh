#!/bin/bash

set -o errexit
set -o xtrace

# configuration
DOCKERAPP=sso-test-app
DOCKERSERVICE=sso-test-service
STATUS=0
TMP=$(mktemp -dt 005_sso.XXXXXX)

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

# Test SSO
cf create-service sso-routing default ${DOCKERSERVICE}
cf bind-route-service ${CF_DOMAIN} ${DOCKERSERVICE} --hostname ${DOCKERAPP}

# restage app
cf restage ${DOCKERAPP} | tee ${TMP}/log

# check if the redirect works
url=$(grep urls ${TMP}/log | cut -f 2- -d " " | head -n 1)

loginpage=${TMP}/loginpage
cookies=${TMP}/cookies.txt

login="$(curl -w "%{url_effective}\n" \
    -c ${cookies} -L -s -k -S ${url} \
    -o ${loginpage}).do"

uaa_csrf=$(cat ${loginpage} | \
    sed -n 's/.*name="X-Uaa-Csrf"\s\+value="\([^"]\+\).*/\1/p')

curl -b ${cookies} -c ${cookies} -L -v ${login} \
    --data "username=${CF_USERNAME}&password=${CF_PASSWORD}&X-Uaa-Csrf=${uaa_csrf}" \
    --insecure \
    > ${TMP}/sso.url \
    2>&1

cookie="$(grep "Cookie: ssoCookie" ${TMP}/sso.url)"
httpcode="$(grep "200 OK" ${TMP}/sso.url)"

if [ -z "${cookie}" -o -z "${httpcode}" ];
then
  echo "ERROR: SSO redirect failed"
  STATUS=1
fi

# unbind route
cf unbind-route-service ${CF_DOMAIN} ${DOCKERSERVICE} -f --hostname ${DOCKERAPP}
cf delete-service -f ${DOCKERSERVICE}
cf delete -f ${DOCKERAPP}

# delete space
cf delete-space -f ${CF_SPACE}

# delete org
cf delete-org -f ${CF_ORG}

rm -rf ${TMP}
exit ${STATUS}
