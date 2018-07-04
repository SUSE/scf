#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #
## Remove CF_ variables not used by the test.

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)
CF_TCP_DOMAIN=${CF_TCP_DOMAIN:-tcp-$(random_suffix).${CF_DOMAIN}}
CF_SEC_GROUP="${CF_SEC_GROUP:-sg-$(random_suffix)}"

## # # ## ### Login & standard entity setup/cleanup ### ## # #
## Remove operations not relevant to the test

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete-space -f "${CF_SPACE}"
    cf delete-org -f "${CF_ORG}"

    cf delete-shared-domain -f "${CF_TCP_DOMAIN}"
    cf delete-security-group -f "${CF_SEC_GROUP}"

    set -o errexit
}
trap login_cleanup EXIT ERR

# target, login, create work org and space
cf api --skip-ssl-validation "api.${CF_DOMAIN}"
cf auth "${CF_USERNAME}" "${CF_PASSWORD}"

cf create-org "${CF_ORG}"
cf target -o "${CF_ORG}"

cf create-space "${CF_SPACE}"
cf target -s "${CF_SPACE}"

cf create-security-group "${CF_SEC_GROUP}" <(echo '[
    { "destination": "0.0.0.0/0", "protocol": "all" }
]')
cf bind-security-group "${CF_SEC_GROUP}" "${CF_ORG}" "${CF_SPACE}" --lifecycle staging
cf bind-security-group "${CF_SEC_GROUP}" "${CF_ORG}" "${CF_SPACE}" --lifecycle running

## # # ## ### Test-specific configuration ### ## # #
## Remove and extend as needed

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## # # ## ### Test-specific code ### ## # #
## For custom cleanup retrap the signals EXIT & ERR to run a custom
## function, and chain to login_cleanup inside. Remove if not needed.

# Registry app names -> locations
declare -A registries=(
    [secure-registry]="https://secure-registry.${CF_DOMAIN}" # Router SSL cert
    [insecure-registry]="https://insecure-registry.${CF_DOMAIN}:20005"       # Self-signed SSL cert
)


function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    for registry in "${!registries[@]}" ; do
        cf delete -f "${registry}"
    done
    cf delete-route -f "${CF_DOMAIN}" --hostname secure-registry
    cf delete-route -f "${CF_TCP_DOMAIN}" --port 20005
    cf delete-shared-domain -f "${CF_TCP_DOMAIN}"

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# set up tcp routing for the invalid-cert registry
cf delete-shared-domain -f "${CF_TCP_DOMAIN}" || true

cf create-shared-domain "${CF_TCP_DOMAIN}" --router-group default-tcp
cf update-quota default --reserved-route-ports -1

# Deploy the registry
cp "${SELFDIR}/../test-resources/docker-uploader/manifest.yml" \
    /var/vcap/packages/docker-distribution/manifest.yml
cp "${SELFDIR}/../test-resources/docker-uploader/config.yml" \
    /var/vcap/packages/docker-distribution/config.yml
cp /var/vcap/packages/acceptance-tests-brain/bin/docker-uploader \
    /var/vcap/packages/docker-distribution/bin/
cp /var/vcap/packages/acceptance-tests-brain/bin/registry \
    /var/vcap/packages/docker-distribution/bin/
(
    cd "/var/vcap/packages/docker-distribution/"
    cf push -f manifest.yml \
        --var domain="${CF_DOMAIN}" \
        --var tcp-domain="${CF_TCP_DOMAIN}"
)

cf apps

for regname in "${!registries[@]}" ; do
    registry="${registries[${regname}]}"
    # Wait for the registry to be available
    while ! curl -kv "${registry}/v2/" ; do
        sleep 1
    done
    curl --fail "http://uploader.${CF_DOMAIN}/" -d "registry=${registry}" -d "name=image" || {
        cf logs uploader --recent
        cf logs "${regname}" --recent
        exit 1
    }
done

result=0
for regname in "${!registries[@]}" ; do
    registry="${registries[${regname}]}"
    cf push "from-${regname}" --docker-image "${registry##*//}/image:latest" || {
        result=$(( result + $?))
        cf logs --recent "from-${regname}"
    }
done

exit "${result}"
