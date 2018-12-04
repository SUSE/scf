#! /usr/bin/env bash

# This is a temporary patch needed to expose credhub to users having
# the CF core components using it. This patch will go away when
# credhub becomes mandatory for CF core components and we are caught
# to that version of CF.

set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- cloud_controller_ng.yml.erb
+++ cloud_controller_ng.yml.erb
@@ -159,15 +159,6 @@ routing_api:
   routing_client_secret: <%= p("uaa.clients.cc_routing.secret") %>
 <% end %>
 
-<% if_link("credhub") do |credhub| %>
-credhub_api:
-  internal_url: <%= "https://#{p("credhub_api.hostname")}:#{credhub.p("credhub.port")}" %>
-  <% if_p("credhub_api.external_url") do |url| %>
-  external_url: <%= url %>
-  <% end %>
-  ca_cert_path: "/var/vcap/jobs/cloud_controller_ng/config/certs/credhub_ca.crt"
-<% end %>
-
 credential_references:
   interpolate_service_bindings: <%= p("cc.credential_references.interpolate_service_bindings") %>
 
PATCH

touch "${SENTINEL}"

exit 0
