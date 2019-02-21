#! /usr/bin/env bash

# This is a temporary patch needed to make kube-dns work for BPM-managed jobs.
# This will go away with the transition to the cf-operator, which will not require BPM anymore.

set -e

PATCH_DIR=/var/vcap/jobs-src/tps/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb	2018-11-30 11:09:48.346891523 -0800
+++ bpm.yml.erb	2019-01-30 11:30:18.275929455 -0800
@@ -4,3 +4,10 @@
   executable: /var/vcap/packages/tps/bin/tps-watcher
   args:
     - --configPath=/var/vcap/jobs/tps/config/tps_watcher_config.json
+  unsafe:
+    unrestricted_volumes:
+    - path: /etc/hostname
+    - path: /etc/hosts
+    - path: /etc/resolv.conf
+    - path: /etc/ssl
+    - path: /var/lib/ca-certificates
PATCH

# Notes on "unsafe.unrestricted_volumes":
#
# - The first three mounts are required to make DNS work in the nested
#   container created by BPM for the job to run in.
#
# - The remainder are required to give the job access to the system
#   root certificates so that it actually can verify the certs given
#   to it by its partners (like the router-registrar).

touch "${SENTINEL}"

exit 0
