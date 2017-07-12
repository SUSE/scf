#!/bin/bash
set -o errexit -o nounset -o xtrace
rm -rf /var/vcap/data/garden/*
# Ensure that runc and container processes can stat everything
chmod ugo+rx /var/vcap/data/garden
