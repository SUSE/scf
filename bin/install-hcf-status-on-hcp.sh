#!/bin/bash
set -e

CURDIR=$(cd "$(dirname "$0")"; pwd)/

# Usage
read -d '' usage <<USAGE || true
Usage:
  install-hcf-status-on-hcp.sh

  Must be run in the HCP dev harness Vagrant directory.
  Installs HCF dev scripts and prerequisites on the HCP dev harness node.
USAGE

if [ "${1}" == "--help" ]; then echo "${usage}"; exit 1; fi

# Verification to see that we're in the HCP vagrant directory
if [ -f "./setup_node.sh" ] && [ -f "./setup_master.sh" ]; then
  vagrant status node 2>&1 1>/dev/null
else
  echo "This script must be run from the HCP dev harness Vagrant directory." >&2
  exit 1
fi

tmpfile=/tmp/hcf-on-hcp-installer.ssh
vagrant ssh-config node > $tmpfile

# Copy hcf-status over to the node
echo "Seting up an hcf dir ..."
ssh -F "$tmpfile" node 'bash -c "mkdir -p ~/hcf/"'
echo "Copying hcf tools to HCP dev harness node ..."
scp -F "$tmpfile" -prq ${CURDIR}/../container-host-files/* node:~/hcf/

# Install prerequisites
echo "Installing prerequisites ..."
ssh -F $tmpfile node 'bash -s' <<SCRIPT > /dev/null
if ! type y2j 2>&1 > /dev/null; then
  sudo /home/vagrant/hcf/opt/hcf/bin/tools/install_y2j.sh
fi
SCRIPT

# Done - print message on how to use it
cat <<HOWTO

Done. HCF tools are installed on HCP.
To check status in HCP, vagrant ssh to the HCP node and run:
  sudo ~/hcf/opt/hcf/bin/hcf-status
HOWTO
