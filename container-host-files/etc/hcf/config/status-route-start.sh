#!/bin/bash

# the /container-host-files directory is a host directory mounted on the container at runtime
./container-host-files/opt/hcf/bin/docker/install_docker.sh root
./container-host-files/opt/hcf/bin/tools/install_y2j.sh

tar -xzf ./container-host-files/etc/hcf/lib/gotty_linux_amd64.tar.gz -C /usr/bin

# Monit doesn't have /usr/local/bin in its PATH
ln -s /usr/local/bin/y2j /usr/bin/y2j

# Monitor the gotty process (It won't show up in hcf-status, but it'll still restart on crash)
cat <<EOF > /var/vcap/monit/gotty.monitrc
check process gotty
  matching "/usr/bin/gotty"
  start program "/usr/bin/nohup /usr/bin/gotty --port 9050 /container-host-files/opt/hcf/bin/hcf-status"
  stop program "/usr/bin/killall /usr/bin/gotty"
  group vcap/var/run
EOF
