#! /usr/bin/env bash

# This is a temporary patch needed to make kube-dns work for BPM-managed jobs.
# This will go away with the transition to the cf-operator, which will not require BPM anymore.

set -e

PATCH_DIR=/var/vcap/jobs-src/routing-api/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -14,3 +14,11 @@ processes:
 
     hooks:
       pre_start: /var/vcap/jobs/routing-api/bin/bpm-pre-start
+    unsafe:
+      unrestricted_volumes:
+      - path: /etc/hostname
+      - path: /etc/hosts
+      - path: /etc/pki
+      - path: /etc/resolv.conf
+      - path: /etc/ssl
+      - path: /var/lib
PATCH

touch "${SENTINEL}"

exit 0
