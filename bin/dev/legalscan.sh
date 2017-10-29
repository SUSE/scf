#!/usr/bin/env bash
PROJECTS="Cloud:Platform:sources:scf Cloud:Platform:sources:buildpacks"
TMPPATH=TMPOSC
rm -r "${TMPPATH}"
mkdir -p "${TMPPATH}" 
pushd "${TMPPATH}" > /dev/null
for PROJECT in ${PROJECTS}; do
  osc checkout -M "${PROJECT}"
  pushd "${PROJECT}" > /dev/null
  osc submitrequest ${PROJECT}:reviewed
  popd > /dev/null
done
