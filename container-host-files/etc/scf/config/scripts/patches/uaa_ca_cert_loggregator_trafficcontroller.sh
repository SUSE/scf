#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/loggregator_trafficcontroller/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -50,7 +50,11 @@ processes:
       TRAFFIC_CONTROLLER_DISABLE_ACCESS_CONTROL: "<%= p("traffic_controller.disable_access_control") %>"

       <% if !uaa_host.empty? %>
+      <% if p("uaa.ca_cert") != "" %>
       TRAFFIC_CONTROLLER_UAA_CA_CERT: "/var/vcap/jobs/loggregator_trafficcontroller/config/certs/uaa_ca.crt"
+      <% else %>
+      TRAFFIC_CONTROLLER_UAA_CA_CERT: "/var/lib/ca-certificates/ca-bundle.pem"
+      <% end %>
       <% end %>

       <% if p("traffic_controller.security_event_logging.enabled") %>
PATCH

touch "${SENTINEL}"

exit 0
