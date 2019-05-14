#!/usr/bin/env bash

# Make sure we can pass FISSILE_* env variables from the host.

set -o errexit -o xtrace -o verbose

echo "AcceptEnv FISSILE_*" | sudo tee -a /etc/ssh/sshd_config
systemctl restart sshd.service
