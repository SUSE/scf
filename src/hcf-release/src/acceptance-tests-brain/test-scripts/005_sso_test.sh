#!/bin/bash

set -o errexit
set -o xtrace

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
DOCKERAPP=sso-test-app
DOCKERSERVICE=sso-test-service
DOMAIN=$(echo $CF_API | sed -e 's/^[^.]*\.//')
STATUS=0

# login
cf api --skip-ssl-validation ${CF_API}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${ORG}
cf target -o  ${ORG}

# create space
cf create-space ${SPACE}
cf target -s    ${SPACE}

# Push a docker app
cf enable-feature-flag diego_docker
cf push ${DOCKERAPP} -o viovanov/node-env-tiny

# Test SSO
cf create-service sso-routing default ${DOCKERSERVICE}
cf bind-route-service ${DOMAIN} ${DOCKERSERVICE} --hostname ${DOCKERAPP}

# restage app
cf restage ${DOCKERAPP} | tee /tmp/log

# check if the redirect works
url=$(cat /tmp/log | grep urls | cut -f 2- -d " " | head -n 1)
rm /tmp/log

loginpage=/tmp/ssologinpage
cookies=/tmp/ssocookies.txt

login="$(curl -w "%{url_effective}\n" \
    -c ${cookies} -L -s -k -S ${url} \
    -o ${loginpage}).do"

uaa_csrf=$(cat ${loginpage} | \
    sed -n 's/.*name="X-Uaa-Csrf"\s\+value="\([^"]\+\).*/\1/p')

curl -b ${cookies} -c ${cookies} -L -v $login \
    --data "username=${CF_USERNAME}&password=${CF_PASSWORD}&X-Uaa-Csrf=${uaa_csrf}" \
    --insecure \
    > /tmp/sso.url \
    2>&1

cat ${cookies} | sed -e 's/^/COOKIES| /'
cat /tmp/sso.url | sed -e 's/^/SSO____| /'

cookie="$(cat   /tmp/sso.url | grep "Cookie: ssoCookie")"
httpcode="$(cat /tmp/sso.url | grep "200 OK")"

if [ -z "$cookie" -o -z "$httpcode" ];
then
  echo "ERROR: SSO redirect failed"
  STATUS=1
fi

# unbind route
cf unbind-route-service ${DOMAIN} ${DOCKERSERVICE} -f --hostname ${DOCKERAPP}
cf delete-service -f ${DOCKERSERVICE}
cf delete -f ${DOCKERAPP}

# delete space
cf delete-space -f ${SPACE}

# delete org
cf delete-org -f ${ORG}

exit $STATUS
