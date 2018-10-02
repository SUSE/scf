#!/bin/bash
## # # ## ### Tracing and common configuration ### ## # #

# __Attention__
# This tests assumes that the kernel modules `nfs` and `nfsd` are
# already loaded.

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

# Shorter handle, and shows up in the log.
NS="${KUBERNETES_NAMESPACE}"
SC="${KUBERNETES_STORAGE_CLASS_PERSISTENT}"

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

SGROUP=${SELFDIR}/../test-resources/nfs_secgroup.json
SMOUNT=${SELFDIR}/../test-resources/nfs_mount.json
SKUBEC=${SELFDIR}/../test-resources/nfs_server_kube.yaml
PORAPP=${SELFDIR}/../test-resources/persi-acceptance-tests/assets/pora

TMP=$(mktemp -dt 011_nfspersi.XXXXXX)

## # # ## ### Test-specific code ### ## # #

function test_cleanup() {
    trap "" EXIT ERR
    set +o errexit

    # See why pora failed to start
    cf logs pora --recent

    # Delete the app, the associated service, block it from use again
    cf delete -f pora
    cf delete-service -f myVolume
    cf disable-service-access persi-nfs

    # Unbind security groups from containers that stage and run apps
    cf unbind-staging-security-group nfs-test
    cf unbind-running-security-group nfs-test

    cf delete-security-group -f nfs-test

    # Remove the test server
    kubectl delete -n "${NS}" -f "${SKUBEC}"

    rm -rf "${TMP}"

    set -o errexit
    login_cleanup
}
trap test_cleanup EXIT ERR

# Launch the NFS server to use by the service (See SMOUNT), and wait
# for it to be ready.

function wait() {
    while ! ( kubectl get pods -n "$1" | awk '{ if ((match($2, /^([0-9]+)\/([0-9]+)$/, c) && c[1] != c[2] && !match($3, /Completed/)) || !match($3, /STATUS|Completed|Running/)) { print ; exit 1 } }' )
    do
	sleep 10
    done
}

# Replace the placeholder storage class for persistent volumes with
# the actual class provided by the execution environment.
SKUBEC=${SELFDIR}/../test-resources/nfs_server_kube.yaml
sed -e "s/storage-class: \"persistent\"/storage-class: \"${SC}\"/" \
    < "${SKUBEC}" \
    > "${TMP}/nfs_server_kube.yaml"
SKUBEC="${TMP}/nfs_server_kube.yaml"

kubectl create -n "${NS}" -f "${SKUBEC}"
wait "${NS}"

# Server of the NFS volume to use, as name (pulled from the kube config)
SNAME="$(grep '^  name:' "${SKUBEC}" | awk '{print $2}' | sed -e "s/\"//g")"

# Server of the NFS volume to use, as IP address (pulled from kube runtime via name)
SADDR="$(kubectl describe service -n "${NS}" "${SNAME}" | grep ^IP | awk '{print $2}')"

# Now that we have an NFS server, with an exportable volume, we can
# configure it for actual export.
##
# - Permissions for all
# - Declare as NFS export (insecure = allow any origin port)
# - Update the NFS master tables to include the new export

echo > "${TMP}/export" '/exports/foo *(rw,insecure)'
kubectl cp "${TMP}/export" "${NS}/${SNAME}-0:/etc/exports.d/foo.exports"

kubectl exec -n "${NS}" "${SNAME}-0" -- chmod a+rwx /exports/foo
kubectl exec -n "${NS}" "${SNAME}-0" -- exportfs -a

# Fix IP in the various configuration files
sed < ${SGROUP} > ${TMP}/nfs_secgroup.json  -e "s|192.168.77.77|${SADDR}|"
sed < ${SMOUNT} > ${TMP}/nfs_mount.json     -e "s|192.168.77.77|${SADDR}|"

SGROUP="${TMP}/nfs_secgroup.json"
SMOUNT="${TMP}/nfs_mount.json"

# Show the security group, for debugging.
echo ======================== ; cat "${SGROUP}" ; echo ========================
echo ======================== ; cat "${SMOUNT}" ; echo ========================

# Create a security group which allows access to the nfs server
# Deploy the pora app of the pats, and bind it to a persi service

cf create-security-group       nfs-test ${SGROUP}
cf bind-running-security-group nfs-test
cf bind-staging-security-group nfs-test

cd $PORAPP
cf push pora --no-start

cf enable-service-access persi-nfs
cf create-service        persi-nfs Existing myVolume -c "$(cat "${SMOUNT}")"

cf bind-service pora myVolume -c '{"uid":"1000","gid":"1000"}'
cf start pora

APP=pora.${CF_DOMAIN}
PATTERN='Hello Persistent World!'

# Test that the app is available
curl "${APP}"

# Test that the app can write to the volume of the bound service
curl "${APP}/write" | grep "${PATTERN}"

# Test that we can create, read, chmod, and delete a file.  We check
# the curl results in part, and, more importantly the pod holding the
# actual volume in part.

FNAME=$(curl "${APP}/create")

kubectl exec -n "${NS}" "${SNAME}-0" -- ls /exports/foo | grep "${FNAME}"
kubectl exec -n "${NS}" "${SNAME}-0" -- grep "${PATTERN}" "/exports/foo/${FNAME}"

curl "${APP}/read/${FNAME}" | grep "${PATTERN}"

curl "${APP}/chmod/${FNAME}/755"
kubectl exec -n "${NS}" "${SNAME}-0" -- ls -l "/exports/foo/${FNAME}" | grep '^-rwxr-xr-x '

curl "${APP}/delete/${FNAME}"
