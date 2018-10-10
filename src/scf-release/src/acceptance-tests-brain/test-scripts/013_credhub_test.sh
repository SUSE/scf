#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

# Shorter handle, and shows up in the log.
NS="${KUBERNETES_NAMESPACE}"

CH_CLI=credhub
CH_SERVICE="https://credhub.${CF_DOMAIN}"

## # # ## ### Login & standard entity setup/cleanup ### ## # #

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete-space -f "${CF_SPACE}"
    cf delete-org   -f "${CF_ORG}"

    set -o errexit
}
trap login_cleanup EXIT ERR

# target, login, create work org and space
cf api --skip-ssl-validation "api.${CF_DOMAIN}"
cf auth "${CF_USERNAME}" "${CF_PASSWORD}"

cf create-org "${CF_ORG}"
cf target -o  "${CF_ORG}"

cf create-space "${CF_SPACE}"
cf target -s    "${CF_SPACE}"

## # # ## ### Test-specific configuration ### ## # #
## Remove and extend as needed

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ask a pod for the name of the relevant secret. This handles HA
# properly, and query after a rotation as well.

# Regarding the use of `nats` below:
# - Wanted a central pod/job which when missing indicates/causes much
#   bigger trouble than failing brain tests. I.e. if that is missing
#   we should never reach the tests. Of course, there are more than
#   just `nats` which would do. It was just the one which popped into
#   my mind.

SECRET=$(kubectl get pods --namespace "${NS}" \
		 -o jsonpath='{.items[?(.metadata.name=="nats-0")].spec.containers[?(.name=="nats")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}')

CH_SECRET="$(kubectl get secrets --namespace "${NS}" "${SECRET}" \
		     -o jsonpath="{.data['uaa-clients-credhub-user-cli-secret']}"|base64 -d)"
CLIENT=credhub_user_cli

TMP="$(mktemp -dt "$(basename "${0}" .sh).XXXXXX")"

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    rm -rf "${TMP}"
    
    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# Target the credhub kube service, via the registered gorouter endpoint
"${CH_CLI}" api  --skip-tls-validation --server "${CH_SERVICE}"

# Log into credhub
"${CH_CLI}" login --client-name="${CLIENT}" --client-secret="${CH_SECRET}"

# Insert ...
"${CH_CLI}" set -n FOX -t value -v 'fox over lazy dog' > ${TMP}/fox
"${CH_CLI}" set -n DOG -t user -z dog -w fox           > ${TMP}/dog

# Retrieve ...
"${CH_CLI}" get -n FOX > ${TMP}/fox2
"${CH_CLI}" get -n DOG > ${TMP}/dog2

# Show (in case of failure) ...
for i in fox fox2 dog dog2
do
    echo __________________________________ ${i}
    cat "${TMP}/${i}"
done
echo __________________________________

# Check ...

grep 'name: /FOX'        "${TMP}/fox"
grep 'type: value'       "${TMP}/fox"
grep 'value: <redacted>' "${TMP}/fox"

grep 'name: /FOX'               "${TMP}/fox2"
grep 'type: value'              "${TMP}/fox2"
grep 'value: fox over lazy dog' "${TMP}/fox2"

id=$(awk '/^id:/ { print $2 }' < "${TMP}/fox")
grep "^id: ${id}$" "${TMP}/fox2"

grep 'name: /DOG'        "${TMP}/dog"
grep 'type: user'        "${TMP}/dog"
grep 'value: <redacted>' "${TMP}/dog"

grep 'name: /DOG'        "${TMP}/dog2"
grep 'type: user'        "${TMP}/dog2"

id=$(awk '/^id:/ { print $2 }' < "${TMP}/dog")
grep "^id: ${id}$" "${TMP}/dog2"

grep 'password: fox' "${TMP}/dog2"
grep 'username: dog' "${TMP}/dog2"

# Not checking the `password_hash` (it is expected to change from run
# to run, due to random seed changes, salting)
#
# Similarly, `version_created_at` is an ever changing timestamp.

exit
