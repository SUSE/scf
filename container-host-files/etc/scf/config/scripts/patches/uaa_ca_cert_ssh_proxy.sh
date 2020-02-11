#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/ssh_proxy/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- ssh_proxy.json.erb
+++ ssh_proxy.json.erb
@@ -43,7 +43,11 @@
     token_url = "#{p("diego.ssh_proxy.uaa.url")}:#{p("diego.ssh_proxy.uaa.port")}/oauth/token"

     if_p("diego.ssh_proxy.uaa.ca_cert") do |value|
-      config[:uaa_ca_cert] = "/var/vcap/jobs/ssh_proxy/config/certs/uaa/ca.crt"
+      if value != "" then
+        config[:uaa_ca_cert] = "/var/vcap/jobs/ssh_proxy/config/certs/uaa/ca.crt"
+      else
+        config[:uaa_ca_cert] = "/var/lib/ca-certificates/ca-bundle.pem"
+      end
     end

     config[:uaa_token_url] = token_url
PATCH

touch "${SENTINEL}"

exit 0
