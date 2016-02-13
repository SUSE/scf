#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

if [[ $# < 2 || -z "$1" || -z "$2" ]]; then
  echo <<HELP
  Usage: create-release.sh <RELEASE_PATH> <RELEASE_NAME>"
  RELEASE_PATH must be relative to the root of hcf-infrastructure
HELP
  exit 1
fi

release_path=$1
release_name=$2

docker run \
    --interactive \
    --tty \
    --rm \
    --volume /home/vagrant/.bosh:/root/.bosh \
    --volume $ROOT/:$ROOT/ \
    helioncf/hcf-pipeline-ruby-bosh \
    bash -l -c "rbenv global 2.2.3 && bosh create release --dir ${ROOT}/${release_path} --force --name ${release_name}"
