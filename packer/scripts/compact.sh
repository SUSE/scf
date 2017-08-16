#!/bin/bash

zypper --non-interactive clean --all

dd if=/dev/zero of=/junk bs=1M || /bin/true
rm -f /junk

sync
