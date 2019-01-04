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

if [ "${FORCE}" == "1" ]; then
	rm -f "${DONE}" 2>/dev/null
fi

function get_phase() {
	kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.status.phase}'
}

function check_for_log_dir() {
	kubectl exec "${POD}" -n "${NS}" -- bash -c "[ -d /var/vcap/sys/log ]" 2>/dev/null
}

if [ ! -f "${DONE}" ]; then
	rm -rf "${KLOG:?}/${NS:?}"
	BASE_DIR="${KLOG}/${NS}"
	mkdir -p ${BASE_DIR}

	# Retrieving all the pods
	PODS=($(kubectl get pods -n cf -o jsonpath='{.items[*].metadata.name}'))

	for POD in "${PODS[@]}"; do

		echo "Dumping logs for pod: ${POD}"

		POD_DIR="${BASE_DIR}/${POD}"
		mkdir -p ${POD_DIR}

		# Get the CF logs inside the pod if there are any
		if [ "$(get_phase)" != 'Succeeded' ]; then
			if [ check_for_log_dir ]; then
				kubectl cp -n "${NS}" "${POD}":/var/vcap/sys/log/ "${POD_DIR}/" 2>/dev/null
			fi
		fi

		# Retrieving all the containers within a pod
		CONTAINERS=($(kubectl get pods "${POD}" -n cf -o jsonpath='{.spec.containers[*].name}'))

		# Iterate over containers and dump logs
		for CONTAINER in "${CONTAINERS[@]}"; do

			CON_DIR="${POD_DIR}/${CONTAINER}"
			mkdir -p ${CON_DIR}

			# Get the pod logs - previous may not be there if it was successful on the first run.
			# Unfortunately we can't get anything past the previous one
			kubectl logs "${POD}" -n "${NS}" -c ${CONTAINER} >"${CON_DIR}/kube.log"
			kubectl logs "${POD}" -n "${NS}" -c ${CONTAINER} >"${CON_DIR}/kube-previous.log" 2>/dev/null || true
			kubectl describe po "${POD}" --namespace "${NS}" >"${CON_DIR}/describe-pod.txt"
		done

	done

	# Unzip any logrotated files so the lookup can read them
	gunzip -r "${KLOG}"

	kubectl get all --export=true -n "${NS}" -o yaml >"${KLOG}/${NS}/resources.yaml"
	kubectl get events --export=true -n "${NS}" -o yaml >"${KLOG}/${NS}/events.yaml"

	touch "${DONE}"
fi
