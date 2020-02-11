#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/eirini-ssh-proxy/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- eirini-ssh-proxy.json.erb
+++ eirini-ssh-proxy.json.erb
@@ -13,8 +13,11 @@


     if_p("eirini-ssh-proxy.uaa.ca_cert") do |value|
-      config[:uaa_ca_cert] = "/var/vcap/jobs/eirini-ssh-proxy/config/certs/uaa/ca.crt"
-    end
+      if value != "" then
+        config[:uaa_ca_cert] = "/var/vcap/jobs/eirini-ssh-proxy/config/certs/uaa/ca.crt"
+      else
+        config[:uaa_ca_cert] = "/var/lib/ca-certificates/ca-bundle.pem"
+      end    end

     if_p("eirini-ssh-proxy.cc.ca_cert") do |value|
       config[:cc_api_ca_cert] = "/var/vcap/jobs/eirini-ssh-proxy/config/certs/cc/cc_api_ca_cert.crt"
PATCH

touch "${SENTINEL}"

exit 0
