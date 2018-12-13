#! /usr/bin/env bash

# This is a temporary patch needed to make kube-dns work for BPM-managed jobs.
# This will go away with the transition to the cf-operator, which will not require BPM anymore.

set -e

PATCH_DIR=/var/vcap/jobs-src/gorouter/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -13,3 +13,11 @@ processes:
     pre_start: /var/vcap/jobs/gorouter/bin/bpm-pre-start
   capabilities:
   - NET_BIND_SERVICE
+  unsafe:
+    unrestricted_volumes:
+    - path: /etc/hostname
+    - path: /etc/hosts
+    - path: /etc/hosts
+    - path: /etc/resolv.conf
+    - path: /etc/ssl
+    - path: /var/lib
PATCH

touch "${SENTINEL}"

exit 0
