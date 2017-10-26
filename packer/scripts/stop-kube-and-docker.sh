#!/bin/sh

set -o errexit
set -o verbose

systemctl stop kube-apiserver kube-controller-manager kube-proxy kube-scheduler kubelet docker