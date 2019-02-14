#! /usr/bin/env bash

# This is a temporary patch needed to make kube-dns work for BPM-managed jobs.
# This will go away with the transition to the cf-operator, which will not require BPM anymore.

set -e

PATCH_DIR=/var/vcap/jobs-src/blobstore/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb	2019-01-30 11:11:35.430797836 -0800
+++ bpm.yml.erb	2019-01-30 11:31:22.672012691 -0800
@@ -7,6 +7,13 @@
       writable: true
   ephemeral_disk: true
   persistent_disk: true
+  unsafe:
+    unrestricted_volumes:
+    - path: /etc/hostname
+    - path: /etc/hosts
+    - path: /etc/resolv.conf
+    - path: /etc/ssl
+    - path: /var/lib/ca-certificates
 - name: url_signer
   executable: /var/vcap/packages/blobstore_url_signer/bin/blobstore_url_signer
   ephemeral_disk: true
@@ -14,3 +21,10 @@
     - --secret=<%= p("blobstore.secure_link.secret") %>
     - --network=unix
     - --laddr=/var/vcap/data/blobstore/signer.sock
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
