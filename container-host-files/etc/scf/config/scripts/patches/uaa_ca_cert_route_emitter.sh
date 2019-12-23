#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/route_emitter/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- route_emitter.json.erb
+++ route_emitter.json.erb
@@ -130,7 +130,11 @@
       config[:oauth][:client_name] = p("uaa.client_name")
       config[:oauth][:client_secret] = p("uaa.client_secret")
       config[:oauth][:skip_cert_verify] = p("uaa.skip_cert_verify")
-      config[:oauth][:ca_certs] = "#{conf_dir}/certs/uaa/ca.crt"
+      if p("uaa.ca_cert") != "" then
+        config[:oauth][:ca_certs] = "#{conf_dir}/certs/uaa/ca.crt"
+      else
+        config[:oauth][:ca_certs] = "/var/lib/ca-certificates/ca-bundle.pem"
+      end
     end
   end

PATCH

touch "${SENTINEL}"

exit 0
