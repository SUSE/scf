#!/usr/bin/env bash

# This script pulls in the various cf-*-release submodules so the
# VM can use them.

ROOT=$(dirname $(dirname $(readlink -f $0)))
cd ${ROOT}
cd src
for dir in * ; do
  cd $dir
  # `git submodule update --init --recursive` failed sometimes - no idea why
  git submodule init
  git submodule update --recursive
  test -x scripts/update && bash -ex scripts/update
  cd ..
done
