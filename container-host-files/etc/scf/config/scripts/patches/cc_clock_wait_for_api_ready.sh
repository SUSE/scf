#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_clock/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- cloud_controller_clock_ctl.erb	2018-02-22 18:03:26.188000000 +0000
+++ cloud_controller_clock_ctl.erb	2018-02-22 18:03:12.932000000 +0000
@@ -21,6 +21,17 @@
   mkdir -p "${RUN_DIR}"
 }
 
+function wait_for_api_ready() {
+  echo "Waiting for api to be ready"
+
+  api_url="<%= p("cc.external_protocol") %>://<%= p("cc.internal_service_hostname") %>:<%= p("cc.external_port") %>/v2/info"
+
+  while ! curl --silent --connect-timeout 5 --fail --header "Accept:application/json" ${api_url} > /dev/null
+  do
+    sleep 60
+  done
+}
+
 case $1 in
 start)
   setup_environment
@@ -29,6 +40,8 @@
 
   echo $$ > "$PIDFILE"
 
+  wait_for_api_ready
+
   exec /var/vcap/jobs/cloud_controller_clock/bin/cloud_controller_clock
   ;;
 
PATCH

touch "${SENTINEL}"

exit 0
