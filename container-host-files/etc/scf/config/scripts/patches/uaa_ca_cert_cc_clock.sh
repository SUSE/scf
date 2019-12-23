#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_clock/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- cloud_controller_ng.yml.erb
+++ cloud_controller_ng.yml.erb
@@ -145,7 +145,11 @@ db: &db

 uaa:
   internal_url: <%= "https://#{p("cc.uaa.internal_url")}:#{p("uaa.ssl.port")}" %>
+  <% if p("uaa.ca_cert") != "" %>
   ca_file: /var/vcap/jobs/cloud_controller_clock/config/certs/uaa_ca.crt
+  <% else %>
+  ca_file: /var/lib/ca-certificates/ca-bundle.pem
+  <% end %>
   <% if_link("cloud_controller_internal") do |cc_internal| %>
   client_timeout: <%= cc_internal.p("cc.uaa.client_timeout")%>
   <% end %>
PATCH

touch "${SENTINEL}"

exit 0
