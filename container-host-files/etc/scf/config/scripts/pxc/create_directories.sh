#!/usr/bin/env bash

set -o errexit

# Create missing log directory.
mkdir -p /var/vcap/sys/log/pxc-mysql

# This empty directory will be properly initialized by the pxc-mysql pre-start script.
mkdir -p /var/vcap/store/pxc-mysql

exit 0
