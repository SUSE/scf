#!/bin/sh

set -o errexit
set -o verbose

# Get predefined version of k
wget https://github.com/SUSE/kctl/releases/download/v0.0.12/kctl-linux-amd64 -O /usr/local/bin/k
chmod +x /usr/local/bin/k
