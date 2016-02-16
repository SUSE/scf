#!/usr/bin/env bash

# This script pulls in the various cf-*-release submodules so the
# VM can use them.

function has_upstream() {
    git rev-parse @{u} > /dev/null 2>&1
}

ROOT=$(dirname $(dirname $(readlink -f $0)))
cd ${ROOT}
cd src
# `git submodule update --init --recursive` failed sometimes - no idea why
( git submodule init && git submodule update --recursive ) || true

# Some of the submodules contain files called scripts/update -- run them
for dir in * ; do
  if [[ ! -d "$dir" || ! -x "$dir/scripts/update" ]] ; then
    continue
  fi
  cd $dir
  case $dir in
      diego-release)
	  # Deal with upstream error https://github.com/cloudfoundry-incubator/diego-release#132 by running the pertinent code from scripts/update
	  has_upstream && git pull
	  if [[ "$(git --version | grep 'version 1.7')x" != "x" ]]; then
	      git submodule foreach --recursive git submodule sync && git submodule update --init --recursive
	  else
	      git submodule sync --recursive && git submodule foreach --recursive git submodule sync  && git submodule update --init --recursive
	  fi
	  ;;
      *)
	  bash -ex scripts/update
	  ;;
  esac
  cd ..
done
