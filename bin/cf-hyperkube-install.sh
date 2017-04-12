#Usage: https://github.com/hpcloud/hcf/blob/develop/docs/kube.md
#!/bin/bash
set -ex

cd ; cd hcf
make hyperkube
cd ; cd uaa-fissile-release/
#Run UAA
kubectl create namespace uaa
kubectl create -n uaa -f kube/bosh/
kubectl create -n uaa -f kube-test/exposed-ports.yml

#Build CF
kubectl create namespace cf
cd ; cd hcf
make vagrant-prep
bash bin/settings/kube/ca.sh
bin/generate-dev-certs.sh cf bin/settings/certs.env
make kube

#run cf
kubectl create -n cf -f ./kube/bosh
kubectl create -n cf -f ./kube/bosh-task/post-deployment-setup.yml
kubectl create -n cf -f ./kube/bosh-task/autoscaler-create-service.yml
kubectl create -n cf -f ./kube/bosh-task/sso-create-service.yml
