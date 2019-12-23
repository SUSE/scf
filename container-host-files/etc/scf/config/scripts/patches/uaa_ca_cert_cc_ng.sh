#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- cloud_controller_ng.yml.erb
+++ cloud_controller_ng.yml.erb
@@ -203,7 +203,11 @@ uaa:
   internal_url: <%= "https://#{p("cc.uaa.internal_url")}:#{p("uaa.ssl.port")}" %>
   resource_id: <%= p("cc.uaa_resource_id") %>
   client_timeout: <%= p("cc.uaa.client_timeout")%>
+  <% if p("uaa.ca_cert") != "" %>
   ca_file: /var/vcap/jobs/cloud_controller_ng/config/certs/uaa_ca.crt
+  <% else %>
+  ca_file: /var/lib/ca-certificates/ca-bundle.pem
+  <% end %>
   <% if_p("uaa.cc.token_secret") do |token_secret| %>
   symmetric_secret: "<%= token_secret %>"
   <% end %>
PATCH

touch "${SENTINEL}"

exit 0
