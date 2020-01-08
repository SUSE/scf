#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/log-cache-cf-auth-proxy/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -27,7 +27,11 @@ processes:
     CAPI_COMMON_NAME:   "<%= p('cc.common_name') %>"

     UAA_ADDR:          "<%= p('uaa.internal_addr') %>"
+  <% if p("uaa.ca_cert") != "" %>
     UAA_CA_PATH:       "<%= "#{certDir}/uaa_ca.crt" %>"
+  <% else %>
+    UAA_CA_PATH:       "/var/lib/ca-certificates/ca-bundle.pem"
+  <% end %>
     UAA_CLIENT_ID:     "<%= p('uaa.client_id') %>"
     UAA_CLIENT_SECRET: "<%= p('uaa.client_secret') %>"
     SKIP_CERT_VERIFY:  "<%= p('skip_cert_verify') %>"
PATCH

touch "${SENTINEL}"

exit 0
