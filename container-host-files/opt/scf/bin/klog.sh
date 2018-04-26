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

if [ ! -f "${DONE}" ]; then
    mkdir -p "${KLOG}/${NS}"
    rm -rf "${KLOG:?}/${NS:?}/"*

    PODS=$(kubectl get pods --namespace "${NS}" --output name --show-all=true | sed 's/pods\///')

    for POD in ${PODS}; do
        DIR=${KLOG}/${NS}/${POD}

        mkdir -p "${DIR}"

        # Get the CF logs inside the pod if there are any
        if [ "$(kubectl get pod "${POD}" --namespace "${NS}" --output=jsonpath='{.status.phase}')" != 'Succeeded' ] && \
                kubectl exec "${POD}" --namespace "${NS}" -- bash -c "[ -d /var/vcap/sys/log ]" 2> /dev/null; then
            # Mask the exit status of tar because it complains if files were written while it was reading them
            kubectl exec "${POD}" --namespace "${NS}" -- bash -c "cd /var/vcap/sys/log && (tar --warning=no-file-changed -cf - * || true)" | ( cd "${DIR}" && tar xf -)
        fi

        # Get the pod logs - previous may not be there if it was successful on the first run.
        # Unfortunately we can't get anything past the previous one
        kubectl logs "${POD}" --namespace "${NS}" > "${DIR}/kube.log"
        kubectl logs "${POD}" --namespace "${NS}" --previous > "${DIR}/kube-previous.log" 2> /dev/null || true
        kubectl describe pods "${POD}" --namespace "${NS}" > "${DIR}/describe-pod.txt"
    done
    gunzip -r "${KLOG}"

    kubectl get all --export=true --namespace "${NS}" -o yaml > "${KLOG}/${NS}/resources.yaml"
    kubectl get events --export=true --namespace "${NS}" -o yaml > "${KLOG}/${NS}/events.yaml"

    touch "${DONE}"
fi

NEWLINE=0
function lookfor {
    read PATTERN

    cd ${KLOG}
    if grep -c -r -F "${PATTERN}" > .grep; then
        [ "${NEWLINE}" == "1" ] && echo
        NEWLINE=1

        echo ">>> ${PATTERN}"
        echo
        grep -v :0$ .grep

        while read INFO; do
            echo ${INFO}
        done
    fi
}

# any pod with consul agent /var/vcap/sys/log/consul_agent/consul_agent.stdout.log
lookfor <<EOF
[ERR] agent: failed to sync remote state: No known Consul servers

This happened on a consul agent that came up before the consul server,
then abandoned the server as non-functional and then had no servers to
talk with, restarting the pod fixed the issue (though restarting consul
would also fix it).
EOF

read -d '' MSG <<EOF || true
SST has happened twice and should only ever happen once. Probably missing the
IST patch. If that patch is in place then full recovery of MySQL required:

monit stop all # Check for lingering processes and kill them
rm -rf /var/vcap/store/mysql/
/var/vcap/jobs/mysql/bin/pre-start
monit start all
EOF

# mysql pod /var/vcap/sys/log/mysql/mysql.err.log
lookfor <<EOF
[ERROR] WSREP: SST failed: 1 (Operation not permitted)

${MSG}
EOF

# mysql pod /var/vcap/sys/log/mysql/mysql.err.log
lookfor <<EOF
[Warning] InnoDB: Cannot open table mysql/gtid_slave_pos from the internal data dictionary of InnoDB

${MSG}
EOF

# mysql pod /var/vcap/sys/log/mysql/mysql.err.log
lookfor <<EOF
[Warning] WSREP: no nodes coming from prim view, prim not possible

Nodes all shut down improperly, MySQL must be manually rebootstrapped. Will fail
if the IST patch has not been applied.
EOF

# mysql pod /var/vcap/sys/log/mysql/mysql.err.log
lookfor <<EOF
[Warning] WSREP: Failed to prepare for incremental state transfer

IST addresses are misconfigured, likely a <= 4.0.1 cluster, manual
patch must be applied and MySQL must be recovered manually.

Not sure exactly when/why this occurs. Perhaps when the primary node
has gone away (as was the case here). The only restitution seems to be
to full recover the mysql node (and ensure the IST patch is done):

monit stop all # Check for lingering processes and kill them
rm -rf /var/vcap/store/mysql/
/var/vcap/jobs/mysql/bin/pre-start
monit start all
EOF

read -d '' MSG <<EOF || true
These point to an etcd that came up in a weird way and thinks there
are other nodes when there are none. Restoration was done by:
monit stop all
rm -rf /var/vcap/store/etcd
# Restart the pod using kubectl
EOF

# etcd pod /var/vcap/sys/log/etcd/etcd_ctl.err.log
lookfor <<EOF
Error:  cannot sync with the cluster using endpoints https://etcd-

${MSG}
EOF

# etcd pod /var/vcap/sys/log/etcd/etcd.stderr.log
# duplicate of previous error?
lookfor <<EOF
etcdserver: publish error: etcdserver: request timed out

${MSG}
EOF

# mysql pods /var/vcap/sys/log/mysql/mysql.err.log
lookfor <<EOF
SST disabled due to danger of data loss. Verify data and bootstrap the cluster

IST is probably disabled so it's falling back to this, this happens on
4.0.1 clusters, the fix is complicated as it involves manually
patching.
EOF

# consul pod /var/vcap/sys/log/consul_agent/consul_agent.stdout.log
lookfor <<EOF
Only one node should be in bootstrap mode, not adding Raft peer.

This occurs when two consul nodes race to bootstrap. Usually deleting
the consul pods (so HCP makes new ones) fixes this.
EOF

# cc-bridge pod /var/vcap/sys/log/stager/stager.stdout.log
lookfor <<EOF
"CellCommunicationError","message":"unable to communicate to compatible cells"

This occurs whet the diego cells don't reconnect properly to the bbs
(diego-database). A restart of the diego-cell pods should fix it (and
you should make sure you only have one instance of diego-database running too).
EOF
