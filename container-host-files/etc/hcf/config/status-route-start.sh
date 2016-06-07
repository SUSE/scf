#!/bin/bash

# the /container-host-files directory is a host directory mounted on the container at runtime
./container-host-files/opt/hcf/bin/docker/install_docker.sh root
./container-host-files/opt/hcf/bin/tools/install_y2j.sh

wget https://github.com/yudai/gotty/releases/download/v0.0.13/gotty_linux_amd64.tar.gz -O - | tar -xzC /usr/bin

# This script has to exit to let the container proceed, so gotty must be run in the background
nohup gotty --port 9050 watch --color /container-host-files/opt/hcf/bin/hcf-status &
