#!/usr/bin/env bash

OSC_BASE_PATH=Cloud:Platform:sources:scf
TMPPATH=TMPOSC
rm -r "$TMPPATH"
mkdir -p "$TMPPATH" 
pushd "$TMPPATH" > /dev/null
osc checkout -M $OSC_BASE_PATH
pushd "$OSC_BASE_PATH" > /dev/null

for PACKAGE in `ls`
do
  curl -v -X POST http://legaldb.suse.de/packages -d api=https://api.opensuse.org/ -d project=$OSC_BASE_PATH -d package=$PACKAGE -d external_link=SCF -d priority=1
done
popd > /dev/null
popd > /dev/null
