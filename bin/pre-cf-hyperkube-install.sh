#Usage: https://github.com/hpcloud/hcf/blob/develop/docs/kube.md
#!/bin/bash
set -ex

cd ; git clone https://github.com/hpcloud/uaa-fissile-release.git

#install Go
wget https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.8.1.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin:/home/vagrant/go/bin

#set gopath
export GOPATH=/home/vagrant/go/

cd uaa-fissile-release/
git submodule update --init --recursive

source .envrc

#install ruby
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:brightbox/ruby-ng
sudo apt update
sudo apt-get install ruby2.3

sudo gem install bosh_cli
sudo gem install bundler

docker pull ubuntu:14.04

#avoid Gem dependency issue
sed -i "s/ruby '2\.3\.1'/ruby '2.3.3'/g" ~/uaa-fissile-release/src/cf-mysql-release/src/cf-mysql-broker/Gemfile


#Build UAA
go get github.com/square/certstrap
source generate-certs.sh
cd ; cd uaa-fissile-release/
bosh create release --dir src/cf-mysql-release --force --name cf-mysql
bosh create release --dir src/uaa-release --force --name uaa
bosh create release --dir src/hcf-release --force --name hcf
fissile build layer compilation
fissile build layer stemcell
fissile build packages
fissile build images
fissile build kube -k kube/ --use-memory-limits=false \
    -D $(echo env/*.env | tr ' ' ',')
fissile show image | xargs -i@ docker tag @ "${FISSILE_DOCKER_REGISTRY}/@"

#exit from the vagrant box to set env for scf build
exit