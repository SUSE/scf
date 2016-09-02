#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

fissile show properties --output json | \
docker run \
    --interactive \
    --rm \
    --volume ${HOME}/.bosh:/root/.bosh \
    --volume $ROOT/:$ROOT/ \
    helioncf/hcf-pipeline-ruby-bosh \
    bash -l -c "rbenv global 2.2.3 && ${ROOT}/bin/config-validator.rb"
