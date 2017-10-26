#!/bin/sh

set -o errexit
set -o verbose

wget -O - https://kubernetes-helm.storage.googleapis.com/helm-v2.6.2-linux-amd64.tar.gz \
    | tar xz -C /usr/local/bin --no-same-owner --strip-components=1 linux-amd64/helm

/usr/local/bin/helm init
