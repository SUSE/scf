#!/bin/bash

# NOTE: This script needs to be run *before* upgrading!
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

recover_crashed_node() {
  local pod=$1

  kubectl exec --namespace hcf "${pod}" -- /var/vcap/packages/mariadb/bin/mysqld --wsrep-recover &> /dev/null
  kubectl exec --namespace hcf "${pod}" -- grep "Recovered position" /var/vcap/sys/log/mysql/mysql.err.log | tail -n 1 | awk '{print $8}' | cut -d : -f 2
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

get_uuids() {
  local pods=$*
  local uuids=()

  for pod in ${pods}
  do
    uuids+=($(kubectl exec --namespace hcf "${pod}" -- awk '/^uuid/{print $2}' /var/vcap/store/mysql/grastate.dat))
  done

  echo "${uuids[@]}"
}

set_pod_as_bootstrap() {
  local pod=$1
  kubectl exec --namespace hcf "${pod}" -- sh -c "echo NEEDS_BOOTSTRAP > /var/vcap/store/mysql/state.txt"
}

main() {
  local pods=($(get_mysql_pods))

  echo "Stopping processes"

  for pod in "${pods[@]}"
  do
    stop_mysql_processes "${pod}"
  done

  echo "Finding sequence data"

  # Once the processes are stopped, the sequences are written to disk  
  local sequences=($(get_sequences "${pods[@]}"))
  local uuids=($(get_uuids "${pods[@]}"))

  local latest=0
  local latest_index=0

  # Find the pod with the highest sequence number  
  for idx in $(seq 0 $((${#pods[@]} - 1)))
  do
    if [[ "${uuids[idx]}" = "00000000-0000-0000-0000-000000000000" ]]; then
      echo "Pod ${pods[idx]} does not have a valid UUID, aborting"
      exit 1
    fi

    if [[ "${sequences[idx]}" -eq "-1" ]]; then
      echo "${pods[idx]} has a sequence of -1"
      sequences[idx]=$(recover_crashed_node "${pods[idx]}")
      echo "Discovered ${pods[idx]} sequence = ${sequences[idx]} from log file"
    fi

    if [[ "${sequences[idx]}" -gt "${latest}" ]]; then
      latest="${sequences[idx]}"
      latest_index="${idx}"
    fi
  done

  echo "Highest sequence: ${latest}"

  if [[ "${latest}" -eq "-1" ]]; then
    echo "No valid sequences found, aborting"
    exit 1
  fi

  echo "Bootstrap pod: ${pods[${latest_index}]}"
  set_pod_as_bootstrap "${pods[${latest_index}]}"
}

main
