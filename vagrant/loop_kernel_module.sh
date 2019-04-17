#!/usr/bin/env bash

# Adds the loop kernel module for loading on system startup, as well as loads it immediately.

echo "loop" > /etc/modules-load.d/loop.conf
modprobe loop
