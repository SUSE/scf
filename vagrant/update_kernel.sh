#!/usr/bin/env bash

# Update the kernel to avoid some btrfs issues

zypper --non-interactive addrepo --check --gpgcheck --priority 150 \
    obs://Kernel:stable/standard kernel:stable
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive install --from=kernel:stable kernel-default
