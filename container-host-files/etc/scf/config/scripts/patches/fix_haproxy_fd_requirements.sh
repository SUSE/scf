#! /usr/bin/env bash
set -e

# This file ensures that haproxy is no longer allowed to set file
# descriptor limits (Removal of SYS_RESOURCE). We do this because we
# don't want the tcp-router role to run with full privileges.  This
# may cause some performance issues, as described here:
# https://www.pivotaltracker.com/story/show/128789361 See HCF-1065 for
# the outcome of running performance tests on HCF.

PATCH_DIR="/var/vcap/jobs-src/tcp_router/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' patch_pre_start <<'PATCH' || true
--- bpm.yml.erb	2019-01-31 10:25:30.649627761 -0800
+++ bpm.yml.erb	2019-01-31 11:05:53.716794283 -0800
@@ -8,5 +8,4 @@
       writable: true
   capabilities:
   - NET_BIND_SERVICE
-  - SYS_RESOURCE
   executable: /var/vcap/jobs/tcp_router/bin/tcp_router_ctl
PATCH

cd "$PATCH_DIR"

echo -e "${patch_pre_start}" | patch --force

touch "${SENTINEL}"

exit 0
