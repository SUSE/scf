#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/uaa/templates/bin
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p4 <<'PATCH'
From 30f290c98fb8004b9fc9b276d6b362b971c66cfe Mon Sep 17 00:00:00 2001
From: Mark Yen <mark.yen@suse.com>
Date: Tue, 17 Dec 2019 14:07:45 -0800
Subject: [PATCH] uaa pre-start: SUSE compat

The SUSE update-ca-certificates does not support the --certbundle option
to set the file to output; instead, we will just go directly to p11-kit
to export the certificate bundle in a cusomtizable way.
---
 jobs/uaa/templates/bin/pre-start.erb | 13 ++++++++++---
 1 file changed, 10 insertions(+), 3 deletions(-)

diff --git jobs/uaa/templates/bin/pre-start.erb jobs/uaa/templates/bin/pre-start.erb
index 5870eb4..1285169 100755
--- jobs/uaa/templates/bin/pre-start.erb
+++ jobs/uaa/templates/bin/pre-start.erb
@@ -32,9 +32,16 @@ function build_new_cache_files {
     <% end %>
 
     log "Trying to run update-ca-certificates..."
-    # --certbundle is an undocumented flag in the update-ca-certificates script
-    # https://salsa.debian.org/debian/ca-certificates/blob/master/sbin/update-ca-certificates#L53
-    timeout --signal=KILL 180s /usr/sbin/update-ca-certificates -f -v --certbundle "$(basename "${OS_CERTS_FILE}")"
+    if grep --quiet -- --certbundle /usr/sbin/update-ca-certificates ; then
+        # --certbundle is an undocumented flag in the update-ca-certificates script
+        # https://salsa.debian.org/debian/ca-certificates/blob/master/sbin/update-ca-certificates#L53
+        timeout --signal=KILL 180s /usr/sbin/update-ca-certificates -f -v --certbundle "$(basename "${OS_CERTS_FILE}")"
+    elif type -t trust ; then
+        timeout --signal=KILL 180s trust extract --format=pem-bundle --purpose=server-auth --filter=ca-anchors "${OS_CERTS_FILE}"
+    else
+        echo "Don't know how to extract CA bundle correctly" >&2
+        exit 1
+    fi
 }
 
 function new_cache_files_are_identical {
-- 
2.16.4

PATCH

touch "${SENTINEL}"

exit 0
