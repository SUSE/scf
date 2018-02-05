#!/bin/bash

set -e
set -x

IPADDR=$(ifconfig eth1 | perl -ne 'print $1 if /inet addr:(\S+)/')

perl -n -i -e "print unless /minicap.local/" /etc/dnsmasq.conf
echo "address=/minicap.local/${IPADDR}" >> /etc/dnsmasq.conf

systemctl restart dnsmasq.service

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"minicap.local": ["${IPADDR}"]}
EOF
k delete pod kube-system:kube-dns

kubectl create -f - <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: persistent
provisioner: kubernetes.io/host-path
parameters:
  path: /tmp
EOF

helm install uaa --namespace uaa --set env.DOMAIN=minicap.local --set env.UAA_ADMIN_CLIENT_SECRET=adminsecret --set kube.external_ip=${IPADDR}
