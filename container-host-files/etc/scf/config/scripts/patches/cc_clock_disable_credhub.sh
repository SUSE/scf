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
@@ -272,11 +272,5 @@ routing_api:
   routing_client_secret: <%= p("uaa.clients.cc_routing.secret") %>
 <% end %>
 
-<% if_link("credhub") do |credhub| %>
-credhub_api:
-  internal_url: <%= "https://#{p("credhub_api.hostname")}:#{credhub.p("credhub.port")}" %>
-  ca_cert_path: "/var/vcap/jobs/cloud_controller_clock/config/certs/credhub_ca.crt"
-<% end %>
-
 credential_references:
   interpolate_service_bindings: <%= p("cc.credential_references.interpolate_service_bindings") %>
PATCH

touch "${SENTINEL}"

exit 0
