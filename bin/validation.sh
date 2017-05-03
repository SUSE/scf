#!/bin/bash
set -e

ROOT="$(readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )")"

stampy "${ROOT}/hcf_metrics.csv" "${BASH_SOURCE[0]}" validation start
stampy "${ROOT}/hcf_metrics.csv" "${BASH_SOURCE[0]}" validation::show-properties start

PROPS=fissile-properties-$$.yaml
trap "rm '${PROPS}'" EXIT
fissile show properties --output yaml > ${PROPS}

stampy "${ROOT}/hcf_metrics.csv" "${BASH_SOURCE[0]}" validation::show-properties "done"
stampy "${ROOT}/hcf_metrics.csv" "${BASH_SOURCE[0]}" validation::docker start

docker < ${PROPS} run \
    --interactive \
    --rm \
    --volume ${FISSILE_CACHE_DIR}:/root/.bosh/cache:ro \
    --volume $ROOT/:$ROOT/:ro \
    --env RUBY_VERSION=2.2.3 \
    splatform/hcf-pipeline-ruby-bosh \
    bash --login -c "${ROOT}/bin/config-validator.rb"

stampy "${ROOT}/hcf_metrics.csv" "${BASH_SOURCE[0]}" validation::docker "done"
stampy "${ROOT}/hcf_metrics.csv" "${BASH_SOURCE[0]}" validation "done"
