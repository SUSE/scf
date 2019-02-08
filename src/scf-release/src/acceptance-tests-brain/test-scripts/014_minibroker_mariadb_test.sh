#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #
## Remove CF_ variables not used by the test.

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG="${CF_ORG:-org}-$(random_suffix)"
CF_SPACE="${CF_SPACE:-space}-$(random_suffix)"
CF_TCP_DOMAIN="${CF_TCP_DOMAIN:-tcp-$(random_suffix).${CF_DOMAIN}}"
CF_SEC_GROUP="${CF_SEC_GROUP:-sec-group}-$(random_suffix)"
CF_BROKER="${CF_BROKER:-minibroker}-$(random_suffix)"
CF_APP="${CF_APP:-app}-$(random_suffix)"
CF_SERVICE="${CF_SERVICE:-service}-$(random_suffix)"
MINIBROKER_REPO="${MINIBROKER_REPO:-https://minibroker-helm-charts.s3.amazonaws.com/minibroker-charts/}"
KUBERNETES_REPO="${KUBERNETES_REPO:-https://minibroker-helm-charts.s3.amazonaws.com/kubernetes-charts/}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-minibroker}-$(random_suffix)"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-minibroker}-$(random_suffix)"
KUBE_INSTANCE_NAMESPACE="${KUBE_INSTANCE_NAMESPACE:-minibroker-pods}-$(random_suffix)"

## # # ## ### Login & standard entity setup/cleanup ### ## # #
## Remove operations not relevant to the test

function login_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf delete-space -f "${CF_SPACE}"
    cf delete-org -f "${CF_ORG}"

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

## # # ## ### Test-specific configuration ### ## # #
## Remove and extend as needed

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## # # ## ### Test-specific code ### ## # #
## For custom cleanup retrap the signals EXIT & ERR to run a custom
## function, and chain to login_cleanup inside. Remove if not needed.

# We have some waits in this test, and want to clean things up properly
# (especially the service broker) when we abort.  So in our waits we check that
# nine minutes haven't elapsed; this gives us around a minute to do any clean up
# we need.
DEADLINE="$(date --date=9min +%s)"
function check_deadline() {
    if [ "$(date +%s)" -gt "${DEADLINE}" ] ; then
        printf 'Test took too long (%s more than %s); aborting to clean up correctly\n' \
            "$(date)" \
            "$(date "--date=@${DEADLINE}")" \
            >&2
        exit 1
    fi
}

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    cf logs --recent "${CF_APP}"
    cf env "${CF_APP}"

    for NS in "${KUBE_NAMESPACE}" "${KUBE_INSTANCE_NAMESPACE}" ; do
        if kubectl get namespace "${NS}" ; then
            kubectl get pods --namespace "${NS}"
            for pod in $(kubectl get pods --namespace "${NS}" -o name) ; do
                for container in $(kubectl get --namespace "${NS}" "${pod}" -o jsonpath='{.spec.containers[*].name}') ; do
                    kubectl logs --namespace "${NS}" "${pod}" -c "${container}"
                done
            done
        fi
    done

    cf unbind-service "${CF_APP}" "${CF_SERVICE}"
    if ! cf delete-service -f "${CF_SERVICE}" ; then
        cf purge-service-instance -f "${CF_SERVICE}"
    fi
    cf delete -f "${CF_APP}"
    cf unbind-security-group "${CF_SEC_GROUP}" "${CF_ORG}" "${CF_SPACE}"
    cf delete-security-group -f "${CF_SEC_GROUP}"
    cf delete-service-broker -f "${CF_BROKER}"

    helm delete --purge "${HELM_RELEASE_NAME}"
    for namespace in "${KUBE_NAMESPACE}" "${KUBE_INSTANCE_NAMESPACE}" ; do
        while kubectl get namespace "${namespace}" >/dev/null 2>/dev/null ; do
            kubectl delete namespace "${namespace}"
            sleep 10
        done
    done

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

function wait_for_namespace() {
    local namespace="${1}"
    while true ; do
        check_deadline
        set +o errexit
        kubectl get pods --namespace "${namespace}" --output json | jq --exit-status '
            .items[].status.conditions[] |
            select(.type == "Ready") |
            select(.status != "True") |
            select(.reason != "PodCompleted")
        '
        local ret=$?
        set -o errexit
        case "${ret}" in
            0) true   ;; # More pods
            4) return ;; # No unready pods
            *) exit 1 ;; # Unexpected
        esac
        sleep 10
    done
}

kubectl get namespace "${KUBE_NAMESPACE}" || kubectl create namespace "${KUBE_NAMESPACE}"
helm init --client-only
helm upgrade "${HELM_RELEASE_NAME}" minibroker \
    --install \
    --repo "${MINIBROKER_REPO}" \
    --devel \
    --reset-values \
    --namespace "${KUBE_NAMESPACE}" \
    --set "helmRepoUrl=${KUBERNETES_REPO}" \
    --set "deployServiceCatalog=false" \
    --set "defaultNamespace=${KUBE_INSTANCE_NAMESPACE}" \
    --set "kube.registry.hostname=index.docker.io" \
    --set "kube.organization=splatform" \
    --set "image=minibroker:latest"

wait_for_namespace "${KUBE_NAMESPACE}"

broker_url="http://${HELM_RELEASE_NAME}-minibroker.${KUBE_NAMESPACE}.svc.cluster.local"
for (( i = 0 ; i < 30 ; i ++ )) ; do
    check_deadline
    if curl --fail --header "X-Broker-API-Version: 2.14" -o /dev/null --silent "${broker_url}/v2/catalog"; then
        break
    fi
    sleep 5
done

cf create-service-broker "${CF_BROKER}" user pass "${broker_url}"
cf enable-service-access mariadb
cf create-security-group "${CF_SEC_GROUP}" <(echo '[{
    "protocol": "tcp",
    "destination": "0.0.0.0/0",
    "ports": "3306",
    "description": "Allow MariaDB traffic"
}]')
cf bind-security-group "${CF_SEC_GROUP}" "${CF_ORG}" "${CF_SPACE}"

BROKER_GUID="$(cf curl /v2/service_brokers | jq -r ".resources[] | select(.entity.name == \"${CF_BROKER}\") | .metadata.guid")"
SERVICE_GUID="$(cf curl "/v2/services?q=service_broker_guid:${BROKER_GUID}&q=label:mariadb" | jq -r '.resources[].metadata.guid')"
PLAN_ID="$(cf curl "/v2/services/${SERVICE_GUID}/service_plans" | jq -r '.resources[0].entity.name')"
APP_DIR=${SELFDIR}/../test-resources/pong_matcher_go

DB_NAME="db-$(random_suffix)"
cf create-service mariadb "${PLAN_ID}" "${CF_SERVICE}" -c <(echo "
        { \"db\": { \"name\": \"${DB_NAME}\" }, \"mariadbDatabase\": \"${DB_NAME}\" }
    ") # Need "mariadbDatabase" key for compatibility with old minibroker
cf push "${CF_APP}" --no-start -p "${APP_DIR}"
cf bind-service "${CF_APP}" "${CF_SERVICE}"
cf start "${CF_APP}"
for (( i = 0 ; i < 30 ; i ++ )); do
    check_deadline
    if [ "$(cf curl "/v2/apps/$(cf app "${CF_APP}" --guid)" | jq -r .entity.state)" == "STARTED" ] ; then
        break
    fi
    sleep 10
done

ROUTE_URL="$(cf curl "/v2/apps/$(cf app --guid "${CF_APP}")/route_mappings" | jq -r '.resources[].entity.route_url')"
APP_HOST="$(cf curl "${ROUTE_URL}" | jq -r '.entity.host')"
APP_DOMAIN="$(cf curl "$(cf curl "${ROUTE_URL}" | jq -r '.entity.domain_url')" | jq -r '.entity.name')"

curl -v --fail -X DELETE "http://${APP_HOST}.${APP_DOMAIN}/all"
curl -v --fail -H 'Content-Type: application/json' -X PUT "http://${APP_HOST}.${APP_DOMAIN}/match_requests/firstrequest" -d '{"player": "one"}'
curl -v --fail -H 'Content-Type: application/json' -X PUT "http://${APP_HOST}.${APP_DOMAIN}/match_requests/secondrequest" -d '{"player": "two"}'
curl -v --fail -X GET "http://${APP_HOST}.${APP_DOMAIN}/match_requests/firstrequest"
