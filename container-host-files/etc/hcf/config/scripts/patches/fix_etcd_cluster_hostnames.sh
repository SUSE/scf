set -e

PATCH_DIR="/var/vcap/jobs-src/etcd/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_etcd_bosh_utils <<'PATCH' || true
--- etcd_bosh_utils.sh.erb.orig 2016-09-13 20:13:55.350149403 +0000
+++ etcd_bosh_utils.sh.erb      2016-09-13 20:57:18.652577021 +0000
@@ -27,7 +27,7 @@
   client_protocol = p("etcd.require_ssl") ? "https" : "http"
   peer_protocol = p("etcd.peer_require_ssl") ? "https" : "http"

-  if p("etcd.require_ssl") || p("etcd.peer_require_ssl")
+  if p("etcd.cluster")
     cluster_members = p("etcd.cluster").map do |zone|
       result = []
       for i in 0..zone["instances"]-1
@@ -36,8 +36,7 @@
       result
     end.flatten.join(" ")
   else
-    my_ip = discover_external_ip
-    cluster_members = p("etcd.machines").map { |m| "http://#{m}:4001" }.join(" ")
+    cluster_members = p("etcd.machines").map { |m| "#{client_protocol}://#{m}:4001" }.join(",")
   end
 %>

@@ -45,12 +44,12 @@
 peer_protocol=<%= peer_protocol %>
 listen_peer_url="${peer_protocol}://0.0.0.0:7001"
 cluster_members=<%= cluster_members.gsub(" ", ",") %>

-<% if p("etcd.require_ssl") || p("etcd.peer_require_ssl") %>
+<% if p("etcd.cluster") %>
 advertise_peer_url="${peer_protocol}://${node_name}.<%= p("etcd.advertise_urls_dns_suffix") %>:7001"
 advertise_client_url="${client_protocol}://${node_name}.<%= p("etcd.advertise_urls_dns_suffix") %>:4001"
 <% else %>
-advertise_peer_url="http://<%= my_ip %>:7001"
-advertise_client_url="http://<%= my_ip %>:4001"
+advertise_peer_url="${peer_protocol}://$(hostname -s | sed 's/\(etcd-[0-9]\+\)-.*/\1/').<%= p("etcd.advertise_urls_dns_suffix") %>:7001"
+advertise_client_url="${client_protocol}://$(hostname -s | sed 's/\(etcd-[0-9]\+\)-.*/\1/').<%= p("etcd.advertise_urls_dns_suffix") %>:4001"
 <% end %>

 listen_client_url="${client_protocol}://0.0.0.0:4001"
PATCH

  cd "$PATCH_DIR"
  
  echo -e "${setup_patch_etcd_bosh_utils}" | patch --force
  
  touch "${SENTINEL}"
  fi

METRICS_PATCH_DIR="/var/vcap/jobs-src/etcd_metrics_server/templates"
METRICS_SENTINEL="${METRICS_PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${METRICS_SENTINEL}" ]; then

  read -r -d '' setup_patch_etcd_metrics_server_ctl <<'PATCH' || true
--- etcd_metrics_server_ctl.erb.orig    2016-09-29 16:44:42.807075932 +0000
+++ etcd_metrics_server_ctl.erb 2016-09-29 16:45:46.942871812 +0000
@@ -21,7 +21,7 @@

 function start_etcd_metrics_server() {
   local node_name
-  node_name="<%= name.gsub('_', '-') %>-<%= spec.index %>"
+  node_name="$(hostname -s | sed 's/\(etcd-[0-9]\+\)-.*/\1/')"
 
   /var/vcap/packages/etcd_metrics_server/bin/etcd-metrics-server \
       -index=<%= spec.index %> \
PATCH

  cd "$METRICS_PATCH_DIR"
  
  echo -e "${setup_patch_etcd_metrics_server_ctl}" | patch --force
  
  touch "${METRICS_SENTINEL}"
fi

exit 0
