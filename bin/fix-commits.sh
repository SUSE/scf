#!/usr/bin/env bash
set -ex
ROOT=$(dirname $(cd $(dirname $0) && pwd))
cd ${ROOT}/src
cd cf-release
git checkout d1cdf1b5
git submodule update --recursive --init
cd ../diego-release
git checkout 72b65532
git submodule update --recursive --init
cd ../garden-linux-release
git checkout 149336f
git submodule update --recursive --init
cd ../etcd-release
git checkout 493f44c
git submodule update --recursive --init
cd ../cf-mysql-release
git checkout b655e0f
git submodule update --recursive --init
