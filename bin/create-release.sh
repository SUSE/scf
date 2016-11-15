#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

if [[ $# < 2 || -z "$1" || -z "$2" ]]; then
  cat <<HELP
  Usage: create-release.sh <RELEASE_PATH> <RELEASE_NAME>"
  RELEASE_PATH must be relative to the root of hcf-infrastructure
HELP
  exit 1
fi

release_path=$1
release_name=$2


# Deletes all dev releases before creating a new one.
#
# This is because by default fissile will use the latest (based on semver) dev
# release available when working with a BOSH release.
#
# This is undesirable when working with newer releases, then switching back
# to older ones

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::${release_name} start
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::docker::${release_name} start

# bosh create release calls `git status` (twice), but hcf doesn't need to know if the
# repo is dirty, so stub it out.

docker run \
    --interactive \
    --rm \
    --volume ${HOME}/.bosh:/root/.bosh \
    --volume $ROOT/:$ROOT/ \
    --env RBENV_VERSION="${RUBY_VERSION:-2.2.3}" \
    helioncf/hcf-pipeline-ruby-bosh \
    bash -l -c "echo echo nothing to commit > /usr/local/bin/git && chmod +x /usr/local/bin/git && rm -rf ${ROOT}/${release_path}/dev_releases && bosh --parallel 10 create release --dir ${ROOT}/${release_path} --force --name ${release_name}"
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::docker::${release_name} done

# Convert YAML to JSON to escape strings nicely so the commit hashes don't get confused as floats
# The resulting JSON files are able to be loaded as YAML files by the go-yaml library

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::y2j::${release_name} start
find "${ROOT}/${release_path}/dev_releases/${release_name}" -name \*.yml \
    -exec mv {} /tmp/tmp-yaml-to-json \; \
    -exec sh -c "y2j < /tmp/tmp-yaml-to-json > {}" \; \
    -exec rm /tmp/tmp-yaml-to-json \;

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::y2j::${release_name} done
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::${release_name} done
