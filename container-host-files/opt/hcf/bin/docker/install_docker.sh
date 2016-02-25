#!/bin/bash
set -e

# Usage: install_docker.sh <USER>
# <USER> defaults to "vagrant" if unset
user=${1:-vagrant}

sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates -y
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get install docker-engine=1.10.0-0~trusty -y
sudo usermod -aG docker $user
