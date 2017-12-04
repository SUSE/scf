set -e

PATCH_DIR=/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/lib/cloud_controller/blobstore/webdav
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p4 <<'PATCH'
diff --git lib/cloud_controller/blobstore/webdav/http_client_provider.rb b/lib/cloud_controller/blobstore/webdav/http_client_provider.rb
index c1bde465b..deef157f2 100644
--- lib/cloud_controller/blobstore/webdav/http_client_provider.rb
+++ lib/cloud_controller/blobstore/webdav/http_client_provider.rb
@@ -4,6 +4,7 @@ module CloudController
       def self.provide(ca_cert_path: nil, connect_timeout: nil)
         client = HTTPClient.new
         client.connect_timeout = connect_timeout if connect_timeout
+        client.send_timeout = 360
         client.ssl_config.verify_mode = VCAP::CloudController::Config.config.get(:skip_cert_verify) ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
         client.ssl_config.set_default_paths

PATCH

touch "${SENTINEL}"

exit 0
