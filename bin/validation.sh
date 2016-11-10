#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" validation start

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" validation::show-properties start
fissile show properties --output yaml > $$
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" validation::show-properties done

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" validation::docker start
docker < $$ run \
    --interactive \
    --rm \
    --volume ${HOME}/.bosh:/root/.bosh \
    --volume $ROOT/:$ROOT/ \
    helioncf/hcf-pipeline-ruby-bosh \
    bash -l -c "rbenv global 2.2.3 && ${ROOT}/bin/config-validator.rb"
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" validation::docker done

rm $$
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" validation done
