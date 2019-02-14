set -e

# This file patches the tcp_router pre-start script so it no longer
# allows haproxy to set file descriptor limits. We do this because we don't
# want the tcp-router role to run with full privileges.
# This may cause some performance issues, as described here:
# https://www.pivotaltracker.com/story/show/128789361
# See HCF-1065 for the outcome of running performance tests on HCF.

# It further contains a temporary patch needed to make kube-dns work
# for BPM-managed jobs.  This will go away with the transition to the
# cf-operator, which will not require BPM anymore.

PATCH_DIR="/var/vcap/jobs-src/tcp_router/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' patch_pre_start <<'PATCH' || true
--- bpm.yml.erb	2019-01-31 10:25:30.649627761 -0800
+++ bpm.yml.erb	2019-01-31 11:05:53.716794283 -0800
@@ -8,5 +8,11 @@
       writable: true
   capabilities:
   - NET_BIND_SERVICE
-  - SYS_RESOURCE
   executable: /var/vcap/jobs/tcp_router/bin/tcp_router_ctl
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

cd "$PATCH_DIR"

echo -e "${patch_pre_start}" | patch --force

touch "${SENTINEL}"

exit 0
