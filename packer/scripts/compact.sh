#!/bin/bash

zypper --non-interactive clean --all

dd if=/dev/zero of=/junk bs=1M
rm -f /junk

sync
