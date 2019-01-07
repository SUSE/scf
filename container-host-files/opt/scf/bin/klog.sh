#!/bin/bash

set -e

KLOG=${HOME}/klog

if [ "$1" == "-h" ]; then
  cat <<EOF
usage: $0 [-f] [-v] [INSTANCE_ID]

  -f  forces fetching of all logs even if a cache already exists

  INSTANCE_ID defaults to "scf"
EOF
  exit
fi

FORCE=0
if [ "$1" == "-f" ]; then
  shift
  FORCE=1
fi

NS=${1-scf}
DONE="${KLOG}/${NS}/done"

if [ "${FORCE}" == "1" ] ; then
  rm -f "${DONE}" 2> /dev/null
fi

function get_phase() {
  kubectl get pod "${POD}" --namespace "${NS}" --output=jsonpath='{.status.phase}'
}

function check_for_log_dir() {
  kubectl exec "${POD}" --namespace "${NS}" --container "${CONTAINER}" -- bash -c "[ -d /var/vcap/sys/log/"${CONTAINER}" ]" 2> /dev/null
}

if [ ! -f "${DONE}" ]; then
  rm -rf "${KLOG:?}/${NS:?}"
  BASE_DIR="${KLOG}/${NS}"

  # Retrieving all the pods
  PODS=($(kubectl get pods --namespace "${NS}" --output=jsonpath='{.items[*].metadata.name}'))

  for POD in "${PODS[@]}"; do
    POD_DIR="${BASE_DIR}/${POD}"

    # Retrieving all the containers within a pod
    CONTAINERS=($(kubectl get pods "${POD}" --namespace "${NS}" --output=jsonpath='{.spec.containers[*].name}'))

    # Iterate over containers and dump logs
    for CONTAINER in "${CONTAINERS[@]}"; do

      CON_DIR="${POD_DIR}/${CONTAINER}"
      mkdir -p ${CON_DIR}

      # Get the CF logs inside the pod if there are any
      if [ "$(get_phase)" != 'Succeeded' ] && check_for_log_dir; then
        kubectl cp --namespace "${NS}" --container "${CONTAINER}" "${POD}":/var/vcap/sys/log/"${CONTAINER}"/ "${CON_DIR}/" 2> /dev/null
      fi

      # Get the pod logs - previous may not be there if it was successful on the first run.
      # Unfortunately we can't get anything past the previous one
      kubectl logs "${POD}" --namespace "${NS}" --container "${CONTAINER}" > "${CON_DIR}/kube.log"
      kubectl logs "${POD}" --namespace "${NS}" --container "${CONTAINER}" --previous > "${CON_DIR}/kube-previous.log" 2> /dev/null || true
      kubectl describe pods "${POD}" --namespace "${NS}" > "${CON_DIR}/describe-pod.txt"
    done

  done

  # Unzip any logrotated files so the lookup can read them
  gunzip -r "${KLOG}"

  kubectl get all --export=true --namespace "${NS}" --output=yaml > "${KLOG}/${NS}/resources.yaml"
  kubectl get events --export=true --namespace "${NS}" --output=yaml > "${KLOG}/${NS}/events.yaml"

  touch "${DONE}"
fi

NEWLINE=0
function lookfor {
  read PATTERN

  cd "${KLOG}"
  if grep -c -r -F "${PATTERN}" > .grep; then
    [ "${NEWLINE}" == "1" ] && echo
    NEWLINE=1

    echo ">>> ${PATTERN}"
    echo
    grep -v :0$ .grep

    while read INFO; do
      echo "${INFO}"
    done
  fi
}
