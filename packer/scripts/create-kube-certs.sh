#!/usr/bin/env bash

set -o errexit -o xtrace

export PATH="${PATH}:/usr/local/bin/"

mkdir -p /run/certstrap
certstrap --depot-path "/run/certstrap" init --common-name "CA.kube.vagrant" --passphrase "" --years 10
certstrap --depot-path "/run/certstrap" request-cert --common-name "apiserver" --passphrase "" --ip 127.0.0.1,192.168.77.77,172.17.0.1,10.254.0.1 --domain kubernetes.default.svc,kubernetes.default,kubernetes,localhost
certstrap --depot-path "/run/certstrap" sign "apiserver" --CA "CA.kube.vagrant" --passphrase ""
certstrap --depot-path "/run/certstrap" request-cert --common-name "kubelet" --passphrase "" --ip 127.0.0.1
certstrap --depot-path "/run/certstrap" sign "kubelet" --CA "CA.kube.vagrant" --passphrase ""
mkdir /etc/kubernetes/{certs,ca}
chmod 0400 /run/certstrap/{apiserver,kubelet}.key
mv /run/certstrap/{apiserver,kubelet,CA.kube.vagrant}.{crt,key} /etc/kubernetes/certs/
chown kube:kube /etc/kubernetes/certs/apiserver.{crt,key} /etc/kubernetes/ca/
cp /etc/kubernetes/certs/CA.kube.vagrant.crt /etc/pki/trust/anchors/
update-ca-certificates

# Turn on host path volume provisioning
perl -p -i -e 's@^(KUBE_CONTROLLER_MANAGER_ARGS=)"(.*)"@\1"\2 --enable-hostpath-provisioner --root-ca-file=/etc/kubernetes/ca/ca.pem"@' /etc/kubernetes/controller-manager

# Tell kubelet to use kubedns for DNS, and give it a cluster domain (we don't care which) to have useful /etc/resolv.conf
perl -p -i -e 's@^(KUBELET_ARGS=)"(.*)"@\1"\2 --cluster-dns=10.254.0.254 --cluster-domain=cluster.local --cgroups-per-qos=false --enforce-node-allocatable='"''"' --network-plugin='"'"'kubenet'"'"' --non-masquerade-cidr=172.16.0.0/16 --pod-cidr=172.16.0.0/16 --network-plugin-dir=/usr/lib/cni/ --feature-gates KubeletConfigFile=true --kubeconfig /etc/kubernetes/kubelet-config"@' /etc/kubernetes/kubelet

# Enable RBAC for kubernetes
perl -p -i -e 's@^(KUBE_API_ARGS=)"(.*)"@\1"\2 --authorization-mode=RBAC"@' /etc/kubernetes/apiserver

systemctl daemon-reload
systemctl restart etcd.service kube-apiserver.service kube-controller-manager.service kube-proxy.service kube-scheduler.service kubelet.service
