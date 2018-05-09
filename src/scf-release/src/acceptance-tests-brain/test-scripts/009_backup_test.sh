#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete-space -f ${CF_SPACE}
    cf delete-org -f ${CF_ORG}

    set -o errexit
}
trap login_cleanup EXIT ERR

# target, login, create work org and space
cf api --skip-ssl-validation api.${CF_DOMAIN}
cf auth ${CF_USERNAME} ${CF_PASSWORD}

cf create-org ${CF_ORG}
cf target -o ${CF_ORG}

cf create-space ${CF_SPACE}
cf target -s ${CF_SPACE}

## # # ## ### Test-specific configuration ### ## # #
## Remove and extend as needed

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR=node-env
APP_NAME=${APP_DIR}-$(random_suffix)

## # # ## ### Test-specific code ### ## # #

ORG_ROLES="OrgManager BillingManager OrgAuditor"
SPACE_ROLES="SpaceManager SpaceDeveloper SpaceAuditor"

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete -f ${APP_NAME}

    local role
    for role in $ORG_ROLES ; do
        cf delete-user -f "${CF_ORG}-${role}" || true
    done
    for role in $SPACE_ROLES ; do
        cf delete-user -f "${CF_SPACE}-${role}" || true
    done

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

for role in $ORG_ROLES ; do
    cf create-user "${CF_ORG}-${role}" hunter2
    cf set-org-role "${CF_ORG}-${role}" "${CF_ORG}" "${role}"
done
for role in $SPACE_ROLES ; do
    cf create-user "${CF_SPACE}-${role}" hunter2
    cf set-space-role "${CF_SPACE}-${role}" "${CF_ORG}" "${CF_SPACE}" "${role}"
done

# push an app to save
cd ${SELFDIR}/../test-resources/${APP_DIR}
cf push ${APP_NAME}

# Check that the app is up
curl --head "${APP_NAME}.${CF_DOMAIN}"
curl --head "${APP_NAME}.${CF_DOMAIN}" | head -n1 | grep -w 200

cf backup snapshot

for role in $ORG_ROLES ; do
    cf unset-org-role "${CF_ORG}-${role}" "${CF_ORG}" "${role}"
done
for role in $SPACE_ROLES ; do
    cf unset-space-role "${CF_SPACE}-${role}" "${CF_ORG}" "${CF_SPACE}" "${role}"
done
cf delete -f ${APP_NAME}
cf delete-space -f ${CF_SPACE}
cf delete-org -f ${CF_ORG}

# Check that the org is gone
if cf target -o "${CF_ORG}"; then
    echo "Successfully targeted org ${CF_ORG} after deleting it" >&2
    exit 1
fi

cf backup restore

sleep 60

cf target -o ${CF_ORG} -s ${CF_SPACE}

# check that the roles are restored
get_section() {
    local section
    section="$(echo "${1}" | perl -pe 's@(?!^)([A-Z])@ \1@g ; $_ = uc')"
    awk " BEGIN { s=0 } /^\$/ { s=0 } { if (s) print } /^${section}\$/ { s=1 }"
}
cf org-users "${CF_ORG}"
for role in $ORG_ROLES ; do
    cf org-users "${CF_ORG}" | get_section "${role}" | grep "${CF_ORG}-${role}"
done
cf space-users "${CF_ORG}" "${CF_SPACE}"
for role in $SPACE_ROLES ; do
    cf space-users "${CF_ORG}" "${CF_SPACE}" | get_section "${role}" | grep "${CF_SPACE}-${role}"
done

# check if the app exists again
cf apps | grep ${APP_NAME}

# check that the app is routable
curl --head "${APP_NAME}.${CF_DOMAIN}"
curl --head "${APP_NAME}.${CF_DOMAIN}" | head -n1 | grep -w 200
