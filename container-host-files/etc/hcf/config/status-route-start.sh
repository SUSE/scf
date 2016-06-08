#!/bin/bash

# the /container-host-files directory is a host directory mounted on the container at runtime
./container-host-files/opt/hcf/bin/docker/install_docker.sh root
./container-host-files/opt/hcf/bin/tools/install_y2j.sh

wget https://github.com/yudai/gotty/releases/download/v0.0.13/gotty_linux_amd64.tar.gz -O - | tar -xzC /usr/bin

# Monitor the gotty process (It won't show up in hcf-status, but it'll still restart on crash)
cat <<EOF > /var/vcap/monit/gotty.monitrc
check process gotty
  matching "/usr/bin/gotty"
  start program "/usr/bin/nohup /usr/bin/gotty --port 9050 watch --color /container-host-files/opt/hcf/bin/hcf-status"
  stop program "/usr/bin/killall /usr/bin/gotty"
  group vcap/var/run
EOF
