#!/usr/bin/env bash

# Wait for the pods to be ready.

set -o errexit -o nounset

echo "Waiting for pods to be ready..."
for selector in k8s-app=kube-dns name=tiller ; do
  while ! kubectl get pods --namespace=kube-system --selector "${selector}" 2> /dev/null | grep -Eq '([0-9])/\1 *Running' ; do
    sleep 5
  done
done
