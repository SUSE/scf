#! /usr/bin/env bash

# This exposes uaa.ca_file as a configurable bosh property.

set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- cloud_controller_ng.yml.erb
+++ cloud_controller_ng.yml.erb
@@ -198,7 +198,7 @@ uaa:
   internal_url: <%= "https://#{p("cc.uaa.internal_url")}:#{p("uaa.ssl.port")}" %>
   resource_id: <%= p("cc.uaa_resource_id") %>
   client_timeout: <%= p("cc.uaa.client_timeout")%>
-  ca_file: /var/vcap/jobs/cloud_controller_ng/config/certs/uaa_ca.crt
+  ca_file: <%= p("cc.uaa.ca_file", "/var/vcap/jobs/cloud_controller_ng/config/certs/uaa_ca.crt") %>
   <% if_p("uaa.cc.token_secret") do |token_secret| %>
   symmetric_secret: "<%= token_secret %>"
   <% end %>

PATCH

touch "${SENTINEL}"

exit 0
