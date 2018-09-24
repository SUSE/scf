#!/usr/bin/env bash

for PACKAGE in $(osc ls Cloud:Platform:buildpacks:dependencies); do
  osc submitrequest --yes --message=legal-review Cloud:Platform:buildpacks:dependencies $PACKAGE Cloud:Platform:sources:buildpacks:reviewed
done

PROJECTS="Cloud:Platform:sources:scf Cloud:Platform:sources:buildpacks Cloud:Platform:sources:sidecars"
for PROJECT in ${PROJECTS}; do
  for PACKAGE in $(osc ls $PROJECT); do
    osc submitrequest --yes --message=legal-review $PROJECT $PACKAGE ${PROJECT}:reviewed
  done
done
