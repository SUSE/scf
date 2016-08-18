#!/bin/sh

set -o errexit -o nounset

JQ_VERSION=1.5

jq_artifact_blob="jq/jq-linux64"

mkdir -p "$(dirname "${BUILD_DIR}/${jq_artifact_blob}")"
curl -L -o "${BUILD_DIR}/${jq_artifact_blob}" https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64
