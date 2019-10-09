#!/usr/bin/env bash

# Create ~/.kube/config file that uses the https endpoint to make
# sure all requests go through rbac validation (requests via the
# http endpoint bypass all validation).

set -o errexit -o nounset -o xtrace

SECRET=$(kubectl get serviceaccount default --namespace kube-system --output jsonpath="{.secrets[0].name}")
CA_CRT=$(kubectl get secrets ${SECRET} --namespace kube-system --output jsonpath="{.data['ca\.crt']}")
TOKEN=$(kubectl get secrets ${SECRET} --namespace kube-system --output jsonpath="{.data['token']}" | base64 --decode)

sudo chown -R vagrant:users ~/.kube

cat <<EOF >>~/.kube/config
kind: Config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: "${CA_CRT}"
    server: https://localhost:6443
  name: local
contexts:
- context:
    cluster: local
    user: admin
  name: admin-context
current-context: admin-context
preferences: {}
users:
- name: admin
  user:
    token: "${TOKEN}"
EOF
