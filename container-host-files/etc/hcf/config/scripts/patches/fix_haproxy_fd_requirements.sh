set -e

# This file patches the router_configurer pre-start script so it no longer
# allows haproxy to set file descriptor limits. We do this because we don't
# want the routing-ha-proxy role to run with full privileges.
# This may cause some performance issues, as described here:
# https://www.pivotaltracker.com/story/show/128789361
# See HCF-1065 for the outcome of running performance tests on HCF.

PATCH_DIR="/var/vcap/jobs-src/router_configurer/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' patch_pre_start <<'PATCH' || true
--- a/jobs/router_configurer/templates/pre-start
+++ b/jobs/router_configurer/templates/pre-start
@@ -16,7 +16,7 @@ function create_directories() {
 function setcap_haproxy() {
     PATH=/var/vcap/packages/haproxy/bin:/var/vcap/packages/haproxy-monitor/bin:$PATH
     DAEMON=$(which haproxy)
-    setcap cap_net_bind_service,cap_sys_resource=+ep $DAEMON
+    setcap cap_net_bind_service=+ep $DAEMON
 }
PATCH

cd "$PATCH_DIR"

echo -e "${patch_pre_start}" | patch --force

touch "${SENTINEL}"

exit 0
