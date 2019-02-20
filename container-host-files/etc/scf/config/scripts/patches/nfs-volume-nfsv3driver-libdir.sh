#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p1 <<'PATCH'
From 56eb140a6751971695d8a8ebf18524fc8900d318 Mon Sep 17 00:00:00 2001
From: Mark Yen <mark.yen@suse.com>
Date: Wed, 30 Jan 2019 10:40:27 -0800
Subject: [PATCH] nfsv3driver: install: Don't rely on "GNU" substring in
 library path

Non-Debian distributions (that haven't done the whole multiarch thing)
will not have the multiarch tuple in the path.
---
 jobs/nfsv3driver/templates/install.erb | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git jobs/nfsv3driver/templates/install.erb jobs/nfsv3driver/templates/install.erb
index 9808062..6f46fb6 100755
--- jobs/nfsv3driver/templates/install.erb
+++ jobs/nfsv3driver/templates/install.erb
@@ -27,7 +27,7 @@ if [ "$codename" == "xenial" ]; then
 fi
 
 # Figure out where the libraries should be installed.
-libdir="/usr/$(dirname "$(ldconfig -p | awk '/gnu\/libc.so/ { print $NF }')")"
+libdir="/usr/$(dirname "$(ldconfig -p | perl -ne "m/\blibc.so.*$(uname -m | tr _ -)/ && print((split)[-1])")")"
 
 # make sure there arent any existing fuse-nfs mounts
 pkill fuse-nfs | true
--
2.16.4
PATCH

touch "${SENTINEL}"

exit 0
