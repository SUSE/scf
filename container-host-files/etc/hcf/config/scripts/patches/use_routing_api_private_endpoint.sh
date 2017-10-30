set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates/
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p4 <<'PATCH'
diff --git bosh/jobs/cloud_controller_ng/templates/cloud_controller_ng.yml.erb bosh/jobs/cloud_controller_ng/templates/cloud_controller_ng.yml.erb
index 2f17279b3..33d21b5d5 100644
--- bosh/jobs/cloud_controller_ng/templates/cloud_controller_ng.yml.erb
+++ bosh/jobs/cloud_controller_ng/templates/cloud_controller_ng.yml.erb
@@ -223,6 +223,7 @@ hm9000:

 <% if p("routing_api.enabled") %>
 routing_api:
+  private_endpoint: <%= "#{p('routing_api.url')}:#{p('routing_api.port')}" %>
   url: <%= "https://api.#{system_domain}/routing" %>
   routing_client_name: "cc_routing"
   routing_client_secret: <%= p("uaa.clients.cc_routing.secret") %>
PATCH

PATCH_DIR=/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/lib/cloud_controller/

patch -d "$PATCH_DIR" --force -p2 <<'PATCH'
diff --git lib/cloud_controller/dependency_locator.rb lib/cloud_controller/dependency_locator.rb
index 6948c3b09..474443ffa 100644
--- lib/cloud_controller/dependency_locator.rb
+++ lib/cloud_controller/dependency_locator.rb
@@ -271,7 +271,7 @@ module CloudController
       )

       skip_cert_verify = @config[:skip_cert_verify]
-      routing_api_url  = HashUtils.dig(@config, :routing_api, :url)
+      routing_api_url  = HashUtils.dig(@config, :routing_api, :private_endpoint)
       RoutingApi::Client.new(routing_api_url, uaa_client, skip_cert_verify)
     end

PATCH

touch "${SENTINEL}"

exit 0
