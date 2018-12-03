#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_worker/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- cloud_controller_ng.yml.erb
+++ cloud_controller_ng.yml.erb
@@ -249,11 +249,6 @@ routing_api:
   routing_client_secret: <%= p("uaa.clients.cc_routing.secret") %>
 <% end %>
 
-<% if_link("credhub") do |credhub| %>
-credhub_api:
-  internal_url: <%= "https://#{p("credhub_api.hostname")}:#{credhub.p("credhub.port")}" %>
-<% end %>
-
 credential_references:
   interpolate_service_bindings: <%= p("cc.credential_references.interpolate_service_bindings") %>
 
PATCH

touch "${SENTINEL}"

exit 0
