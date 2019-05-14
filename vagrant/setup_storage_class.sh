#!/usr/bin/env bash

# Set up the storage class.

if ! kubectl get storageclass persistent 2>/dev/null ; then
  perl -p -e 's@storage.k8s.io/v1beta1@storage.k8s.io/v1@g' \
    "${HOME}/scf/src/uaa-fissile-release/kube-test/storage-class-host-path.yml" | \
  kubectl create -f -
fi
