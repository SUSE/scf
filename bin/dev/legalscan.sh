#!/usr/bin/env bash
PROJECTS="Cloud:Platform:sources:scf Cloud:Platform:sources:buildpacks"
TMPPATH=TMPOSC
rm -r "${TMPPATH}"
mkdir -p "${TMPPATH}" 
pushd "${TMPPATH}" > /dev/null
for PROJECT in ${PROJECTS}; do
  osc checkout -M "${PROJECT}"
  pushd "${PROJECT}" > /dev/null

  for PACKAGE in *
  do
    curl -v -X POST http://legaldb.suse.de/packages -d api=https://api.opensuse.org/ -d project="${PROJECT}" -d package="${PACKAGE}" -d external_link=SCF -d priority=1
  done
  popd > /dev/null
done
