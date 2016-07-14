#!/bin/bash

set -e

# Install files needed for NFS shares
apt-get -qy install nfs-common portmap
