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
@@ -292,7 +292,7 @@ module CloudController
       )

       skip_cert_verify = config.get(:skip_cert_verify)
-      routing_api_url = config.get(:routing_api, :url)
+      routing_api_url = config.get(:routing_api, :private_endpoint)
       RoutingApi::Client.new(routing_api_url, uaa_client, skip_cert_verify)
     end

diff --git lib/cloud_controller/config_schemas/api_schema.rb lib/cloud_controller/config_schemas/api_schema.rb
index 78f53270b..ffb53a10d 100644--- lib/cloud_controller/config_schemas/api_schema.rb
+++ lib/cloud_controller/config_schemas/api_schema.rb
@@ -216,6 +216,7 @@ module VCAP::CloudController

           users_can_select_backend: bool,
           optional(:routing_api) => {
+            private_endpoint: String,
             url: String,
             routing_client_name: String,
             routing_client_secret: String,
PATCH

touch "${SENTINEL}"

exit 0
