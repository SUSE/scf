#!/bin/bash
set -e

# Usage: install_docker.sh <USER>
# <USER> defaults to "vagrant" if unset
user=${1:-vagrant}

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget quota

curl -sSL https://test.docker.com/ | sh

sudo usermod -aG docker $user
