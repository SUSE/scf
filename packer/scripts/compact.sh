#!/bin/bash

apt-get clean

dd if=/dev/zero of=/junk bs=1M
rm -f /junk

sync
