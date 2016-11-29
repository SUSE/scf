#!/bin/bash

## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)
SERVICE_INSTANCE_NAME="mysql-$(random_suffix)"
SELFDIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`
APP_NAME=php-mysql

export PATH="$PATH:${SELFDIR}/../test-resources/assets"

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    # login to cf, during the test the previous login times out
    cf api --skip-ssl-validation api.${CF_DOMAIN}
    cf auth ${CF_USERNAME} ${CF_PASSWORD}

    cf target -o ${CF_ORG} -s ${CF_SPACE}

    cf unbind-service ${APP_NAME} ${SERVICE_INSTANCE_NAME}-cf1

    cf delete-service ${SERVICE_INSTANCE_NAME}-cf1 -f

    hsm delete-instance ${SERVICE_INSTANCE_NAME}-hsm -y

    cf delete -f ${APP_NAME}
    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}

    set -o errexit
}
trap login_cleanup EXIT ERR

# login to cf
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

# create organization
cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

# create space
cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

# push an app
cd ${SELFDIR}/../test-resources/${APP_NAME}
cf push ${APP_NAME}
cd -

# login & create the instance
hsm api https://$HSM_DOMAIN:443 --skip-ssl-validation
hsm login -u $HCP_USERNAME -p $HCP_PASSWORD
hsm create-instance stackato.hpe.mysql 5.5 -f -y -i <(cat <<EOF
{
    "name": "mysql",
    "instance_id": "${SERVICE_INSTANCE_NAME}-hsm"
}
EOF
)

# give hsm time to create the instance
sleep 120

cf hsm api https://$HSM_DOMAIN:443 --skip-ssl-validation
cf hsm login -u $HCP_USERNAME -p $HCP_PASSWORD
echo -e "1\n"|cf hsm enable-service-instance ${SERVICE_INSTANCE_NAME}-hsm ${SERVICE_INSTANCE_NAME}-cf

# bind a service
cf create-service ${SERVICE_INSTANCE_NAME}-cf default ${SERVICE_INSTANCE_NAME}-cf1
cf bind-service ${APP_NAME} ${SERVICE_INSTANCE_NAME}-cf1

# restage the app
cf restage ${APP_NAME}

# upgrade cf
hsm upgrade-instance $HCF_INSTANCE $HCF_PRODUCT_VERSION $HCF_SDL_VERSION -f -y

n=0
echo "Waiting for hcf to migrate"

until [ $n -gt 15 ]
do
    if [ -z "$(hsm list-instances|grep stackato.hpe.hcf|grep ${HCF_SDL_VERSION}|grep running)" ]
    then
	echo "retry $n / 15"
	n=$[$n+1]
	sleep 60
    else
	echo " hcf is running"
	break
    fi
done

# login again and restage the app
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}
cf target -o ${CF_ORG} -s ${CF_SPACE}

cf restage ${APP_NAME}

# check if the app is running
cf apps | grep $APP_NAME | grep started ||
    {
    echo "app is not started"
    exit 1
    }
