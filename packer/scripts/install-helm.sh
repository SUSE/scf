#!/bin/sh

set -o errexit
set -o verbose

wget -O - https://kubernetes-helm.storage.googleapis.com/helm-v2.6.2-linux-amd64.tar.gz \
    | tar xz -C /usr/local/bin --no-same-owner --strip-components=1 linux-amd64/helm

# Set up RBAC permissions for tiller
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

/usr/local/bin/helm init
