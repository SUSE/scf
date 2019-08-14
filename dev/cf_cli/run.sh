#!/bin/bash

set -o errexit -o nounset

namespace="scf"
pod_name="cf-terminal"
api_ip=""
while true; do
  api_ip=$(kubectl describe endpoints -n "${namespace}" scf-router | awk '/^  Addresses:/{ print $2 }')
  if [[ "${api_ip}" != "<none>" ]]; then break; fi
  echo "endpoint not ready..."
  sleep 3
done
admin_password=$(kubectl get secret -n "${namespace}" scf.var-cf-admin-password -o json | jq -r .data.password | base64 --decode)

kubectl delete pod -n "${namespace}" "${pod_name}" || true
kubectl create -n "${namespace}" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: "${pod_name}"
spec:
  hostAliases:
  - ip: "${api_ip}"
    hostnames:
    - "app1.scf.suse.dev"
    - "app2.scf.suse.dev"
    - "app3.scf.suse.dev"
    - "login.scf.suse.dev"
    - "api.scf.suse.dev"
    - "uaa.scf.suse.dev"
    - "doppler.scf.suse.dev"
  containers:
  - name: cf-terminal
    image: governmentpaas/cf-cli
    command: ["bash", "-c"]
    args:
    - |-
      cf api --skip-ssl-validation api.scf.suse.dev
      cf login -u admin -p "${admin_password}"
      cf create-org aiur
      cf target -o aiur
      cf create-space saalok
      cf target -s saalok
      cf enable-feature-flag diego_docker
      sleep 3600000
EOF
