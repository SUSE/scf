#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #
## Remove CF_ variables not used by the test.

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }

if [ -z "${SCF_LOG_HOST:-}" ] ; then
    printf "SCF_LOG_HOST not set\n" >&2
    env | grep SCF_LOG_ | sort >&2
fi

if [[ "${SCF_LOG_HOST}" != *".${KUBERNETES_NAMESPACE}.svc.${KUBERNETES_CLUSTER_DOMAIN}" ]] ; then
    printf "SCF_LOG_HOST (%s) does not end with cluster domain (%s)\n" \
        "${SCF_LOG_HOST}" \
        ".${KUBERNETES_NAMESPACE}.svc.${KUBERNETES_CLUSTER_DOMAIN}" \
        >&2
    env | grep SCF_LOG_ | sort >&2
    exit 1
fi

LOG_SERVICE_NAME="${SCF_LOG_HOST%.${KUBERNETES_NAMESPACE}.svc.${KUBERNETES_CLUSTER_DOMAIN}}"

## # # ## ### Test-specific configuration ### ## # #
## Remove and extend as needed

# Report progress to the user; use as printf
status() {
    local fmt="${1}"
    shift
    printf "\n%b${fmt}%b\n" "\033[0;32m" "$@" "\033[0m"
}

# Report problem to the user; use as printf
trouble() {
    local fmt="${1}"
    shift
    printf "\n%b${fmt}%b\n" "\033[0;31m" "$@" "\033[0m"
}

# helper function to retry a command several times, with a delay between trials
# usage: retry <max-tries> <delay> <command>...
function retry () {
    local max="${1}"
    local delay="${2}"
    local i=0
    shift 2

    while test "${i}" -lt "${max}" ; do
        printf "Trying: %s\n" "$*"
        if eval "$@" ; then
            status ' SUCCESS'
            break
        fi
        trouble '  FAILED'
        status "Waiting ${delay} ..."
        sleep "${delay}"
        i="$(expr "${i}" + 1)"
    done
}

# Location of the test script. All other assets will be found relative
# to this.
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## # # ## ### Test-specific code ### ## # #
## For custom cleanup retrap the signals EXIT & ERR to run a custom
## function, and chain to login_cleanup inside. Remove if not needed.

export PATH="${PATH}:/var/vcap/packages/kubectl/bin"

RUN_SUFFIX=$(uuidgen | tr -dC a-z0-f)

# Start emitting logs as soon as possible to maximize the chance the cron task
# picks up new logs
function cleanup_log_emitter() {
    trap "" EXIT ERR
    set +o errexit
    kill %?emit_log_entries
}

trap cleanup_log_emitter EXIT ERR

function emit_log_entries() {
    while true ; do
        echo "Hello from ${0} @ $(date): ${LOG_SERVICE_NAME}.${RUN_SUFFIX}" \
            | kubectl exec --namespace "${KUBERNETES_NAMESPACE}" api-group-0 -c api-group --stdin -- tee -a "/var/vcap/sys/log/cloud_controller_ng/brains-${RUN_SUFFIX}.log" \
            > /dev/null
        sleep 1
    done
}

(
    # Disable tracing to avoid spamming the wanted traces
    set +o xtrace
    emit_log_entries
) &

function run_in_container() {
    local run_in_api=(
        kubectl exec
        --namespace "${KUBERNETES_NAMESPACE}"
        api-group-0
        --container api-group
        --
    )
    "${run_in_api[@]}" "$@"
}

function test_cleanup() {
    trap "" EXIT ERR

    cleanup_log_emitter

    set +o errexit

    if [ -z "${SUCCEEDED:-}" -a -n "${POD_NAME:-}" ] ; then
        kubectl logs --namespace "${KUBERNETES_NAMESPACE}" "${POD_NAME}"
    fi

    for file in $(run_in_container find /var/vcap/sys/log/cloud_controller_ng/ -iname 'brains-*.log') ; do
        run_in_container rm --force --verbose "${file}"
    done
    for file in $(run_in_container find /etc/rsyslog.d -iname '*-vcap-brains-*.conf') ; do
        run_in_container rm --force --verbose "${file}"
    done

    delete_args=(
        kubectl delete deployment,service
        --namespace "${KUBERNETES_NAMESPACE}"
        --now
        --ignore-not-found
        "${LOG_SERVICE_NAME}"
    )
    "${delete_args[@]}"

    set -o errexit
}
trap test_cleanup EXIT ERR

install_args="zypper --non-interactive install busybox"
nc_args="/usr/bin/busybox nc -ll -p ${SCF_LOG_PORT}"
if [ "${SCF_LOG_PROTOCOL:-tcp}" == "udp" ] ; then
    nc_args="${nc_args} -u"
fi
nc_args="${nc_args} -e /usr/bin/busybox logger -s -t ''"
# Run the test
run_args=(
    kubectl run "${LOG_SERVICE_NAME}"
    --namespace "${KUBERNETES_NAMESPACE}"
    --command
    --port "${SCF_LOG_PORT}"
    --expose
    # We need a new enough version of busybox to have `nc -e`
    --image=opensuse/tumbleweed
    --labels="brains=${LOG_SERVICE_NAME}.${RUN_SUFFIX}"
    --
    /bin/sh -c "${install_args} && ${nc_args}"
)
"${run_args[@]}"

env | grep SCF_LOG_

# Wait for the pod to exist
retry 10 5 kubectl get pods --namespace "${KUBERNETES_NAMESPACE}" --selector "brains=${LOG_SERVICE_NAME}.${RUN_SUFFIX}" --output=wide
# Wait for the pod to be ready
retry 60 5 kubectl get pods --namespace "${KUBERNETES_NAMESPACE}" --selector "brains=${LOG_SERVICE_NAME}.${RUN_SUFFIX}" --output json \
    '|' jq -e "'"'.items[].status.conditions[] | select(.type == "Ready") | select(.status == "True")'"'"

# Find the name of the pod, so we can see its logs
POD_NAME="$(kubectl get pods --namespace "${KUBERNETES_NAMESPACE}" --selector "brains=${LOG_SERVICE_NAME}.${RUN_SUFFIX}" --output=name)"

timeout --kill-after=10m 5m sh -c "kubectl logs --follow --namespace '${KUBERNETES_NAMESPACE}' '${POD_NAME}' | grep --line-buffered --max-count=1 '${LOG_SERVICE_NAME}.${RUN_SUFFIX}'"

SUCCEEDED=true
