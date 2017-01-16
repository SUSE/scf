#!/bin/bash

# NOTE: This script needs to be run before upgrading!
# 
# MySQL pods do not come up correctly after an upgrade. Ensure they can cluster
# correctly by stopping the mysqld processes and setting one of the pods as the
# bootstrap. When the new pods come up, only that one will have the bootstrap
# setting in its volume.

set -euf -o pipefail

get_mysql_pods() {
  kubectl get pods --namespace hcf | awk '/^mysql-[0-9]+-/{print $1}'
}

stop_mysql_processes() {
  local pod=$1
  local x=0
  kubectl exec --namespace hcf "${pod}" monit stop all
  while [ "$x" -lt 60 ] && kubectl exec --namespace hcf "${pod}" -- test -e /var/vcap/sys/run/mysql/mysql.pid; do
	  x=$((x+1))
	  sleep 1
  done
}

get_sequences() {
  local pods=$*
  local sequences=()

  for pod in ${pods}
  do
    sequences+=($(kubectl exec --namespace hcf "${pod}" -- awk '/^seqno/{print $2}' /var/vcap/store/mysql/grastate.dat))
  done

  echo "${sequences[@]}"
}

set_pod_as_bootstrap() {
  local pod=$1
  kubectl exec --namespace hcf "${pod}" -- sh -c "echo NEEDS_BOOTSTRAP > /var/vcap/store/mysql/state.txt"
}

main() {
  local pods=($(get_mysql_pods))

  echo "Shutting down mysql processes"

  for pod in "${pods[@]}"
  do
    stop_mysql_processes "${pod}"
  done

  # Once the processes are stopped, the sequences are written to disk  
  local sequences=($(get_sequences "${pods[@]}"))
 
  local latest=0
  local latest_index=0

  echo "Finding MySQL cluster sequence values"
  
  # Find the pod with the highest sequence number  
  for idx in $(seq 0 $((${#pods[@]} - 1)))
  do
    if [[ "${sequences[idx]}" -eq "-1" ]]; then
      echo "${pods[idx]} has a sequence of -1"
      echo "MySQL nodes need manual intervention before upgrading"
      exit 1
    fi

    if [[ "${sequences[idx]}" -gt "${latest}" ]]; then
      latest="${sequences[idx]}"
      latest_index="${idx}"
    fi
  done
  
  echo "Highest sequence: ${latest}"
  echo "Bootstrap pod: ${pods[${latest_index}]}"
  
  set_pod_as_bootstrap "${pods[${latest_index}]}"
}

main
