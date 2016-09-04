#!/bin/sh

# This patch is from HCF-627
# We don't really deal with IP addresses; instead, we deal in host names.
# This makes it more possible to find the instance in the list so it can give
# a correct index.

set -o errexit -o nounset

PATCH_DIR="/var/vcap/jobs-src/proxy/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "${PATCH_DIR}"

patch -p0 --force <<"EOF"
diff --git a/jobs/proxy/templates/route-registrar.yml.erb b/jobs/proxy/templates/route-registrar.yml.erb
index 8aa3fdf..9e26fec 100644
--- route-registrar.yml.erb
+++ route-registrar.yml.erb
@@ -4,9 +4,9 @@ message_bus_servers:
   user: <%= p('nats.user') %>
   password: <%= p('nats.password') %>
 <% end %>
-<% my_ip = spec.networks.send(p('network_name')).ip %>
-<% proxy_index = p('cf_mysql.proxy.proxy_ips').index(my_ip) %>
-host: <%= my_ip %>
+<% my_host = spec.networks.send(p('network_name')).dns_record_name %>
+<% proxy_index = p('cf_mysql.proxy.proxy_ips').index(my_host) %>
+host: <%= my_host %>
 routes:
 - name: "proxy_<%= index %>"
   port: <%= p('cf_mysql.proxy.api_port') %>
EOF

touch "${SENTINEL}"
exit 0
