#!/bin/bash
set -e

CURDIR=$(cd "$(dirname "$0")"; pwd)/

# Usage
read -d '' usage <<USAGE || true
Usage:
  install-hcf-status-on-hcp-aws.sh <HCP_NODE_IP>

  Installs HCF dev scripts and prerequisites on a HCP node.
  Assumes it can create an SSH connection using the user 'ubuntu'.
USAGE

if [ "${1}" == "--help" ]; then echo "${usage}"; exit 1; fi

if [ -z ${1} ]; then echo "${usage}"; exit 1; else node_ip=$1; fi


# Copy hcf-status over to the node
echo "Seting up an hcf dir ..."
ssh ubuntu@${node_ip} 'bash -c "mkdir -p ~/hcf/"'
echo "Copying hcf tools to HCP dev harness node ..."
scp -prq ${CURDIR}/../container-host-files/* ubuntu@${node_ip}:~/hcf/

# Install prerequisites
echo "Installing prerequisites ..."
ssh ubuntu@${node_ip} 'bash -s' <<SCRIPT > /dev/null
if ! type y2j 2>&1 > /dev/null; then
  sudo /home/ubuntu/hcf/opt/hcf/bin/tools/install_y2j.sh
fi
SCRIPT

# Done - print message on how to use it
cat <<HOWTO

Done. HCF tools are installed on HCP.
To check status in HCP, ssh to the HCP node and run:
  sudo ~/hcf/opt/hcf/bin/hcf-status
HOWTO
