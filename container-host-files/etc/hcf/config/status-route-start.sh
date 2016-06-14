#!/bin/bash

# the /container-host-files directory is a host directory mounted on the container at runtime
./container-host-files/opt/hcf/bin/docker/install_docker.sh root
./container-host-files/opt/hcf/bin/tools/install_y2j.sh

# Monit doesn't have /usr/local/bin in its PATH so we need to make sure gotty and y2j are available form /usr/bin
tar -xzf ./container-host-files/etc/hcf/lib/gotty_linux_amd64.tar.gz -C /usr/bin
ln -s /usr/local/bin/y2j /usr/bin/y2j

# Monitor the gotty process
cat <<EOF > /var/vcap/monit/gotty.monitrc
check process gotty
  matching "/usr/bin/gotty"
  start program "/usr/bin/nohup /usr/bin/gotty --port 9052 /container-host-files/opt/hcf/bin/hcf-status"
  stop program "/usr/bin/killall /usr/bin/gotty"
  group vcap/var/run
EOF
