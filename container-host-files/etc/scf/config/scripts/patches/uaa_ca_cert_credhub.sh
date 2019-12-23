#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/credhub/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- init_key_stores.erb
+++ init_key_stores.erb
@@ -95,6 +95,10 @@ end

 auth_server_ca_certs = p('credhub.authentication.uaa.ca_certs') || []

+if auth_server_ca_certs.empty? || (auth_server_ca_certs.length == 1 && auth_server_ca_certs[0].empty?)
+   auth_server_ca_certs[0] = IO.read('/var/lib/ca-certificates/ca-bundle.pem')
+end
+
 if auth_server_ca_certs.kind_of?(Array) && auth_server_ca_certs.any?
   auth_server_ca_certs.each_with_index do |cert, index|
     cert.scan(/-----BEGIN CERTIFICATE-----[A-z0-9+\/\s=]*-----END CERTIFICATE-----/m).each_with_index do |sub_cert, sub_cert_index|
PATCH

touch "${SENTINEL}"

exit 0
