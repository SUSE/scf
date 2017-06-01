#!/bin/sh

# OpenSUSE only provides libbz2.so.1 and libbz2.so.1.0.6, not libbz2.so.1.0
# We need to figure out why mysqld is being linked against libbz2.so.1.0
# as that shouldn't exist

exec /usr/bin/ln -sf /usr/lib64/libbz2.so.1 /usr/lib64/libbz2.so.1.0

