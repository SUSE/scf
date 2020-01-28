#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/reverse_log_proxy_gateway/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -34,6 +34,10 @@ processes:
       LOG_ADMIN_CLIENT_ID: "<%= p('uaa.client_id') %>"
       LOG_ADMIN_CLIENT_SECRET: "<%= p('uaa.client_secret') %>"
       LOG_ADMIN_ADDR: "<%= p('uaa.internal_addr') %>"
+      <% if p("uaa.ca_cert") != "" %>
       LOG_ADMIN_CA_PATH: "/var/vcap/jobs/reverse_log_proxy_gateway/config/certs/uaa_ca.crt"
+      <% else %>
+      LOG_ADMIN_CA_PATH: "/var/lib/ca-certificates/ca-bundle.pem"
+      <% end %>

       SKIP_CERT_VERIFY: "<%= p('skip_cert_verify') %>"
PATCH

touch "${SENTINEL}"

exit 0
