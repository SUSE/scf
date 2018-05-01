#!/usr/bin/env bash

set -o errexit -o xtrace

# Set up RBAC permissions for kubedns/tiller
kubectl create -f - <<EOF
{ "apiVersion": "rbac.authorization.k8s.io/v1beta1",
  "kind": "ClusterRoleBinding",
  "metadata": { "name": "permissive-system-accounts" },
  "roleRef":{
    "apiGroup": "rbac.authorization.k8s.io",
    "kind": "ClusterRole",
    "name": "cluster-admin"
  },
  "subjects": [
    { "apiGroup": "rbac.authorization.k8s.io",
      "kind": "Group",
      "name": "system:serviceaccounts:kube-system" },
    { "kind": "ServiceAccount",
      "name": "default",
      "namespace":"kube-system" }
  ]
}
EOF
