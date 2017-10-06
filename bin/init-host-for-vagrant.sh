#!/usr/bin/env bash

# This script pulls in the various cf-*-release submodules so the
# VM can use them.

function has_upstream() {
    git rev-parse @{u} > /dev/null 2>&1
}

ROOT=$(dirname $(unset CDPATH ; cd $(dirname $0) && pwd))
cd ${ROOT}/src

# Some of the submodules contain files called scripts/update -- run them
for dir in * ; do
  if [[ ! -d "$dir" || ! -e "$dir/.git" ]] ; then
    continue
  fi
  cd "$dir"
  case "$dir" in
      diego-release)
	  has_upstream && git pull
	  if [[ "$(git --version | grep 'version 1.7')x" != "x" ]]; then
	      git submodule foreach --recursive git submodule sync && git submodule update --init --recursive
	  else
	      git submodule sync --recursive && git submodule foreach --recursive git submodule sync  && git submodule update --init --recursive
	  fi
	  ;;
      *) 
	 if [[  -x "scripts/update" ]] ; then
	    bash -ex scripts/update
	 else
	    git submodule update --init --recursive
	 fi
  esac
  cd ..
done
