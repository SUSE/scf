set -e

PATCH_DIR="/var/vcap/jobs-src/cloud_controller_worker/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' fix_cc_worker_audit_syslog_tag <<'PATCH' || true
--- cloud_controller_worker.yml.erb	2017-01-18 19:06:17.000000000 +0000
+++ cloud_controller_worker.yml.erb.new	2017-05-29 12:01:20.709888123 +0000
@@ -143,7 +143,7 @@
 
 logging:
   file: /var/vcap/sys/log/cloud_controller_worker/cloud_controller_worker.log
-  syslog: vcap.cloud_controller_ng
+  syslog: vcap-cloud_controller_ng
   level: <%= p("cc.logging_level") %>
   max_retries: <%= p("cc.logging_max_retries") %>
PATCH

cd "$PATCH_DIR"

echo -e "${fix_cc_worker_audit_syslog_tag}" | patch --force

touch "${SENTINEL}"

exit 0
