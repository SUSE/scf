#!/usr/bin/env bash
set -o errexit -o nounset
set -x

# Use kube-native service IPs for the CC Uploader and the
# Eirini registry
target="/var/vcap/all-releases/jobs-src/eirini/opi/templates/opi.yml.erb"
cat $target
PATCH='@@ -7,9 +7,9 @@

   cc_certs_secret_name: <%= p("opi.certs_secret_name") %>
   cc_internal_api: <%= p("opi.cc_internal_api") %>
-  cc_uploader_ip: <%= p("opi.cc_uploader_ip") %>
+  cc_uploader_ip: <%= ENV["{{ .Values.deployment_name | upper }}_CC_UPLOADER_SERVICE_HOST"] %>

   registry_address: <%= p("opi.registry_address") %>
   registry_secret_name: bits-service-registry-secret
   eirini_address: <%= p("opi.eirini_address", "https://" + spec.ip + "opi.tls_port") %>
   downloader_image: <%= p("opi.downloader_image") %>'

# Only patch once
if ! patch --reverse --dry-run -f "${target}" <<<"$PATCH" 2>&1  >/dev/null ; then
  patch --verbose "${target}" <<<"$PATCH"
else
  echo "Patch already applied. skipping"
fi
