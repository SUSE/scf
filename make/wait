#!/usr/bin/env bash

set -o errexit -o nounset

while ! ( kubectl get pods --namespace "$1" | awk '{ if ((match($2, /^([0-9]+)\/([0-9]+)$/, c) && c[1] != c[2] && !match($3, /Completed/)) || !match($3, /STATUS|Completed|Running/)) { print ; exit 1 } }' )
do
  sleep 10
done
