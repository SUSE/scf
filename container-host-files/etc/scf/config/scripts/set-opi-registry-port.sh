#!/bin/sh

# Locate the kubectl binary.
kubectl="/var/vcap/packages/kubectl/bin/kubectl"

set +x
export OPI_REGISTRY_NODEPORT=$(${kubectl} get svc -n ${KUBERNETES_NAMESPACE} opi-registry \
                                          -o jsonpath='{.spec.ports[0].nodePort}')
