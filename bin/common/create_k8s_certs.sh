#!/usr/bin/env bash

K8S_VM_IP=${K8S_VM_IP:-192.168.77.77}
certstrap --depot-path "/run/certstrap" init --common-name "CA.kube.vagrant" --passphrase "" --years 10
certstrap --depot-path "/run/certstrap" request-cert --common-name "apiserver" --passphrase "" --ip 127.0.0.1,${K8S_VM_IP},172.17.0.1,10.254.0.1 --domain kubernetes.default.svc,kubernetes.default,kubernetes,localhost
certstrap --depot-path "/run/certstrap" sign "apiserver" --CA "CA.kube.vagrant" --passphrase ""
certstrap --depot-path "/run/certstrap" request-cert --common-name "kubelet" --passphrase "" --ip 127.0.0.1
certstrap --depot-path "/run/certstrap" sign "kubelet" --CA "CA.kube.vagrant" --passphrase ""
mkdir /etc/kubernetes/{certs,ca}
chmod 0400 /run/certstrap/{apiserver,kubelet}.key
mv /run/certstrap/{apiserver,kubelet,CA.kube.vagrant}.{crt,key} /etc/kubernetes/certs/
chown kube:kube /etc/kubernetes/certs/apiserver.{crt,key} /etc/kubernetes/ca/
cp /etc/kubernetes/certs/CA.kube.vagrant.crt /etc/pki/trust/anchors/
update-ca-certificates
