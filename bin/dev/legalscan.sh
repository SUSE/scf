#!/usr/bin/env bash

PROJECTS="Cloud:Platform:sources:scf Cloud:Platform:sources:buildpacks Cloud:Platform:buildpacks:dependencies Cloud:Platform:sources:sidecars"
for SOURCE_OBS_PROJECT in ${PROJECTS}; do
  for PACKAGE in $(osc ls ${SOURCE_OBS_PROJECT}); do
    TARGET_OBS_PROJECT="${SOURCE_OBS_PROJECT}:reviewed"
    osc submitrequest --yes --message=legal-review ${SOURCE_OBS_PROJECT} ${PACKAGE} ${TARGET_OBS_PROJECT}
  done
done
