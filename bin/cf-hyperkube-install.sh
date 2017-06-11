#Usage: https://github.com/SUSE/scf/blob/develop/docs/kube.md
#!/bin/bash
set -ex


eval "$(${HOME}/bin/direnv hook bash)"

#install Go for certstrap
curl https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz | sudo tar -C /usr/local -xz
export PATH=$PATH:/usr/local/go/bin:/home/vagrant/go/bin

#set gopath
export GOPATH=/home/vagrant/go/

git clone https://github.com/hpcloud/uaa-fissile-release.git

#install ruby
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:brightbox/ruby-ng
sudo apt update -y
sudo apt-get install -y ruby2.3

#install gems
sudo gem install bosh_cli
sudo gem install bundler

cd ~/uaa-fissile-release
direnv allow
git submodule update --init --recursive

docker pull ubuntu:14.04 #'fissile build layer compilation' fails without this 

#avoid Gem dependency issue
sed -i "s/ruby '2\.3\.1'/ruby '~> 2.3'/g" ~/uaa-fissile-release/src/cf-mysql-release/src/cf-mysql-broker/Gemfile

#Build UAA
go get github.com/square/certstrap
./generate-certs.sh
cd ~/uaa-fissile-release #generate-certs.sh leaves you in /tmp/
_direnv_hook
bosh create release --dir src/cf-mysql-release --force --name cf-mysql
bosh create release --dir src/uaa-release --force --name uaa
bosh create release --dir src/hcf-release --force --name hcf
pwd
echo $PATH
fissile build layer compilation
fissile build layer stemcell
fissile build packages
fissile build images
fissile build kube -k kube/ --use-memory-limits=false \
    -D $(echo env/*.env | tr ' ' ',')

make -C ~/scf hyperkube	

#Run UAA
kubectl create namespace uaa
kubectl create -n uaa -f kube/bosh/
kubectl create -n uaa -f kube-test/exposed-ports.yml

#Build CF
kubectl create namespace cf
cd ~/scf
source .envrc
make vagrant-prep
bash bin/settings/kube/ca.sh
bin/generate-dev-certs.sh cf bin/settings/certs.env
make kube

#run cf
kubectl create -n cf -f ./kube/bosh
kubectl create -n cf -f ./kube/bosh-task/post-deployment-setup.yml
