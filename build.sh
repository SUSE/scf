#!/bin/bash

docker build -t scf_builder -f bin/common/Dockerfile bin/common/ &&
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD:$PWD \
  scf_builder ${PWD}/bin/common/build.sh
