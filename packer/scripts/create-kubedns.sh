#!/usr/bin/env bash

set -o errexit -o xtrace

curl -s https://raw.githubusercontent.com/SUSE/caasp-services/b0cf20ca424c/contrib/addons/kubedns/dns.yaml | \
  perl -p -e '
    s@clusterIP:.*@clusterIP: 10.254.0.254@ ;
    s@170Mi@256Mi@ ;
    s@70Mi@128Mi@ ;
  ' | \
  kubectl create --namespace kube-system --filename -
