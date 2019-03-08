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
  kubectl exec "${POD}" --namespace "${NS}" --container "${CONTAINER}" -- bash -c "[ -d /var/vcap/sys/log ]" 2> /dev/null
}

if [ ! -f "${DONE}" ]; then
  rm -rf "${KLOG:?}/${NS:?}"
  NAMESPACE_DIR="${KLOG}/${NS}"

  # Retrieving all the pods.
  PODS=($(kubectl get pods --namespace "${NS}" --output=jsonpath='{.items[*].metadata.name}'))

  for POD in "${PODS[@]}"; do
    POD_DIR="${NAMESPACE_DIR}/${POD}"

    # Retrieving all the containers within a pod.
    CONTAINERS=($(kubectl get pods "${POD}" --namespace "${NS}" --output=jsonpath='{.spec.containers[*].name}'))

    # Iterate over containers and dump logs.
    for CONTAINER in "${CONTAINERS[@]}"; do

      CONTAINER_DIR="${POD_DIR}/${CONTAINER}"
      mkdir -p ${CONTAINER_DIR}

      # Get the CF logs inside the pod if there are any.
      if [ "$(get_phase)" != 'Succeeded' ] && check_for_log_dir; then
        kubectl cp --namespace "${NS}" --container "${CONTAINER}" "${POD}":/var/vcap/sys/log/ "${CONTAINER_DIR}/" 2> /dev/null
      fi


      # Get the pod logs - previous may not be there if it was successful on the first run.
      # Unfortunately we can't get anything past the previous one.
      kubectl logs "${POD}" --namespace "${NS}" --container "${CONTAINER}" > "${CONTAINER_DIR}/kube.log"
      kubectl logs "${POD}" --namespace "${NS}" --container "${CONTAINER}" --previous > "${CONTAINER_DIR}/kube-previous.log" 2> /dev/null || true
    done
    
    kubectl describe pods "${POD}" --namespace "${NS}" > "${POD_DIR}/describe-pod.txt"
  done

  kubectl get all --export=true --namespace "${NS}" --output=yaml > "${KLOG}/${NS}/resources.yaml"
  kubectl get events --export=true --namespace "${NS}" --output=yaml > "${KLOG}/${NS}/events.yaml"

  tar -zcf klog.tar.gz "${KLOG}"

  touch "${DONE}"
fi
