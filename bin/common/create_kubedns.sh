#!/usr/bin/env bash

echo "Waiting for kubectl to respond..."
while ! kubectl get pods --all-namespaces; do
  sleep 2
done
echo "Waiting for kube-apiserver to be active..."
while ! systemctl is-active kube-apiserver.service 2>/dev/null >/dev/null; do
  sleep 10
done
perl -p -i -e '
  s@clusterIP:.*@clusterIP: 10.254.0.254@ ;
  s@170Mi@256Mi@ ;
  s@70Mi@128Mi@ ;
' /etc/kubernetes/addons/kubedns.yml
kubectl create --namespace kube-system --filename /etc/kubernetes/addons/kubedns.yml
