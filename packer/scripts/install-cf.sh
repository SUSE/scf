#!/bin/sh

set -o errexit
set -o verbose

# Get predefined version of cf-cli
wget -O - https://s3-us-west-1.amazonaws.com/cf-cli-releases/releases/v6.32.0/cf-cli_6.32.0_linux_x86-64.tgz \
  | tar xz -C /usr/local/bin
