#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p1 <<'PATCH'
From c46738e970913e75d04f0654df6033c6e0ad7d61 Mon Sep 17 00:00:00 2001
From: Mark Yen <mark.yen@suse.com>
Date: Wed, 30 Jan 2019 13:51:36 -0800
Subject: [PATCH] mapfs: install: Support for SUSE

This adds support for SUSE-like systems to install fuse:
- Detect Ubuntu, and keep installing the pre-packaged debs
- Detect SUSE, and use zypper to install fuse.
- Don't use `adduser`, use `useradd`.
---
 jobs/mapfs/templates/install.erb | 39 +++++++++++++++++++++++++--------------
 1 file changed, 25 insertions(+), 14 deletions(-)

diff --git jobs/mapfs/templates/install.erb jobs/mapfs/templates/install.erb
index 7574622..f3cba25 100644
--- jobs/mapfs/templates/install.erb
+++ jobs/mapfs/templates/install.erb
@@ -4,22 +4,33 @@ set -e -x
 
 echo "Installing fuse"
 
-codename=$(lsb_release -c | awk '{print $2}')
-if [ "$codename" == "trusty" ]; then
-  (
-  flock -x 200
-  dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.2-4ubuntu4.14.04.1_amd64.deb
-  ) 200>/var/vcap/data/dpkg.lock
-elif [ "$codename" == "xenial" ]; then
-  (
-  flock -x 200
-  dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.4-1ubuntu3.1_amd64.deb
-  ) 200>/var/vcap/data/dpkg.lock
-fi
+lsb_id() {
+    awk -F= "/^${1}=/ { print \$2}" /etc/os-release | tr -d '"\n'
+}
+
+case "$(lsb_id ID)-$(lsb_id VERSION_ID)" in
+    ubuntu-14.04)
+        (
+            flock -x 200
+            dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.2-4ubuntu4.14.04.1_amd64.deb
+        ) 200>/var/vcap/data/dpkg.lock
+        modprobe fuse
+        ;;
+    ubuntu-16.04)
+        (
+            flock -x 200
+            dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.4-1ubuntu3.1_amd64.deb
+        ) 200>/var/vcap/data/dpkg.lock
+        modprobe fuse
+        ;;
+    *suse-*)
+        # openSUSE / SUSE
+        zypper --non-interactive --quiet install fuse
+        ;;
+esac
 
-modprobe fuse
 groupadd fuse || true
-adduser vcap fuse
+useradd fuse -g vcap
 chown root:fuse /dev/fuse
 cat << EOF > /etc/fuse.conf
 user_allow_other
--
2.16.4
PATCH

touch "${SENTINEL}"

exit 0
