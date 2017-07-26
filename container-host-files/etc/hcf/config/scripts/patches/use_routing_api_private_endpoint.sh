set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates/
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

read -r -d '' setup_patch_cc_yaml <<'PATCH' || true
--- cloud_controller_api.yml.erb
+++ cloud_controller_api.yml.erb
@@ -215,6 +215,7 @@ hm9000:

 <% if p("routing_api.enabled") %>
 routing_api:
+  private_endpoint: <%= "#{p('routing_api.url')}:#{p('routing_api.port')}" %>
   url: <%= "https://api.#{system_domain}/routing" %>
   routing_client_name: "cc_routing"
   routing_client_secret: <%= p("uaa.clients.cc_routing.secret") %>
PATCH

echo -e "${setup_patch_cc_yaml}" | patch --force

PATCH_DIR=/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/lib/cloud_controller/

cd "$PATCH_DIR"

read -r -d '' setup_patch_routing_api_endpoint <<'PATCH' || true
--- dependency_locator.rb
+++ dependency_locator.rb
@@ -240,7 +240,7 @@ module CloudController
       )

       skip_cert_verify = @config[:skip_cert_verify]
-      routing_api_url  = HashUtils.dig(@config, :routing_api, :url)
+      routing_api_url  = HashUtils.dig(@config, :routing_api, :private_endpoint)
       RoutingApi::Client.new(routing_api_url, uaa_client, skip_cert_verify)
     end

PATCH

echo -e "${setup_patch_routing_api_endpoint}" | patch --force

touch "${SENTINEL}"

exit 0
