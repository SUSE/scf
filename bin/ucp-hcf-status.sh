#!/bin/bash

set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

# 1. Copy hcf-status over to the node
echo "Copying hcf tools to UCP dev harness node ..."
sshpass -p "vagrant" ssh -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@192.168.200.3 'bash -c "mkdir -p ~/hcf/"'
sshpass -p "vagrant" scp -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -prq ${ROOT}/container-host-files/* vagrant@192.168.200.3:~/hcf/

# 2. Install prerequisites
echo "Installing prerequisites ..."
sshpass -p "vagrant" ssh -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@192.168.200.3 'bash -s' <<SCRIPT > /dev/null
if ! type y2j > /dev/null; then
  sudo /home/vagrant/hcf/opt/hcf/bin/tools/install_y2j.sh
fi
SCRIPT

# 2. Run hcf-status
echo "Running hcf-status ..."
sshpass -p "vagrant" ssh -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@192.168.200.3 'bash -c "sudo /home/vagrant/hcf/opt/hcf/bin/hcf-status"'
