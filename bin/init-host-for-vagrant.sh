#!/usr/bin/env bash

# This script pulls in the various cf-*-release submodules so the
# VM can use them.

function has_upstream() {
    git rev-parse @{u} > /dev/null 2>&1
}

ROOT=$(dirname $(dirname $(readlink -f $0)))
cd ${ROOT}
cd src
for dir in * ; do
  cd $dir
  # `git submodule update --init --recursive` failed sometimes - no idea why
  git submodule init
  git submodule update --recursive
  case $dir in
      diego-release)
	  # Deal with upstream error https://github.com/cloudfoundry-incubator/diego-release#132
	  has_upstream && git pull
	  if [[ "$(git --version | grep 'version 1.7')x" != "x" ]]; then
	      git submodule foreach --recursive git submodule sync && git submodule update --init --recursive
	  else
	      git submodule sync --recursive && git submodule foreach --recursive git submodule sync  && git submodule update --init --recursive
	  fi
	  ;;
      *)
	  test -x scripts/update && bash -ex scripts/update
	  ;;
  esac
  cd ..
done
