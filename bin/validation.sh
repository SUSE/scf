#!/usr/bin/env bash
set -e

ROOT="$(unset CDPATH ; cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation start
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::scf start
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::scf::show-properties start

PROPS=fissile-properties-$$.yaml
trap "rm -f '${PROPS}'" EXIT
fissile show properties --output yaml > ${PROPS}

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::scf::show-properties "done"
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::scf::docker start

env_args=()
for env_name in "${!FISSILE@}" ; do
    env_args=("${env_args[@]}" --env "${env_name}")
done
docker < ${PROPS} run \
    --interactive \
    --rm \
    --volume ${FISSILE_CACHE_DIR}:/root/.bosh/cache:ro \
    --volume $ROOT/:$ROOT/:ro \
    --env RUBY_VERSION=2.2.3 \
    "${env_args[@]}" \
    "splatform/bosh-cli:${BOSH_CLI_VERSION:-latest}" \
    bash --login -c "${ROOT}/bin/config-validator.rb"
rm "${PROPS}"

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::scf::docker "done"
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::scf "done"

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::uaa start
cd src/uaa-fissile-release
source .envrc
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::uaa::show-properties start

PROPS=fissile-properties-$$.yaml
trap "rm '${PROPS}'" EXIT
fissile show properties --output yaml > ${PROPS}

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::uaa::show-properties "done"
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::uaa::docker start

env_args=()
for env_name in "${!FISSILE@}" ; do
    env_args=("${env_args[@]}" --env "${env_name}")
done
docker < ${PROPS} run \
    --interactive \
    --rm \
    --volume ${FISSILE_CACHE_DIR}:/root/.bosh/cache:ro \
    --volume $ROOT/:$ROOT/:ro \
    --env RUBY_VERSION=2.2.3 \
    "${env_args[@]}" \
    "splatform/bosh-cli:${BOSH_CLI_VERSION:-latest}" \
    bash --login -c "${ROOT}/bin/config-validator.rb"

stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::uaa::docker "done"
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation::uaa "done"
stampy "${ROOT}/scf_metrics.csv" "${BASH_SOURCE[0]}" validation "done"
