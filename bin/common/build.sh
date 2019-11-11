#!/bin/bash

# This script builds the provided scf commit and pushes the resulting docker images to the specified registry.

# Clone scf and checkout commit
#git clone https://github.com/SUSE/scf.git
#cd scf
#git checkout $1
#git submodule sync --recursive && git submodule update --init --recursive && git submodule foreach --recursive "git checkout . && git reset --hard && git clean -dffx"

# Build it
ROOT="$( unset CDPATH ; cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
cd ${ROOT}/../
source .envrc
./bin/common/install_tools.sh
make vagrant-prep
