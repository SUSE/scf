#!/usr/bin/env bash

# Ensure that kubelet is running correctly.

set -o errexit -o nounset -o xtrace

if ! systemctl is-active kubelet.service ; then
  systemctl enable --now kubelet.service
fi
