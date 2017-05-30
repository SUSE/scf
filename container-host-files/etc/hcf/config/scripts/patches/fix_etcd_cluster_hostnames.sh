set -e

# NOTE to developers:
#   TLDR, this is a local patch for a local problem, and upstreaming
#   it is contra-indicated.
#
#   In a bit more detail, this patch works around our use of k8s style
#   hostnames (Format <role>-<index>-<random-id>). A vanilla CF
#   distribution does not use this style of hostnames and therefore
#   does not need the patch either.

PATCH_DIR="/var/vcap/jobs-src/etcd/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_etcd_bosh_utils <<'PATCH' || true
--- etcd_bosh_utils.sh.erb.orig	2017-05-17 13:37:05.054264713 -0700
+++ etcd_bosh_utils.sh.erb	2017-05-19 13:20:42.590606579 -0700
@@ -36,20 +36,22 @@
   end
 
   def advertise_peer_url
-    if p("etcd.require_ssl") || p("etcd.peer_require_ssl")
+    if p("etcd.cluster")
       "#{peer_protocol}://#{node_name}.#{p("etcd.advertise_urls_dns_suffix")}:7001"
     else
-      my_ip = discover_external_ip
-      "http://#{my_ip}:7001"
+      # [1] Note, the hostname|sed transformer is inserted by ERB into
+      # the shell script, at the place invoking this def. Then when
+      # the script runs it is actually run to perform the substitution.
+      "#{peer_protocol}://$(hostname -s | sed 's/\(etcd-[0-9]\+\)-.*/\1/').#{p("etcd.advertise_urls_dns_suffix")}:7001"
     end
   end
 
   def advertise_client_url
-    if p("etcd.require_ssl") || p("etcd.peer_require_ssl")
+    if p("etcd.cluster")
       "#{client_protocol}://#{node_name}.#{p("etcd.advertise_urls_dns_suffix")}:4001"
     else
-      my_ip = discover_external_ip
-      "http://#{my_ip}:4001"
+      # See [1] above
+      "#{client_protocol}://$(hostname -s | sed 's/\(etcd-[0-9]\+\)-.*/\1/').#{p("etcd.advertise_urls_dns_suffix")}:4001"
     end
   end
 
@@ -65,7 +67,7 @@
   end
 
   def consistency_checker_cluster_members
-    if p("etcd.require_ssl") || p("etcd.peer_require_ssl")
+    if p("etcd.cluster")
       cluster_member_urls = p("etcd.cluster").map do |zone|
         result = []
         for i in 0..zone["instances"]-1
@@ -75,8 +77,7 @@
       end.flatten.join(",")
       return cluster_member_urls
     else
-      my_ip = discover_external_ip
-      cluster_member_ips = p("etcd.machines").map { |m| "http://#{m}:4001" }.join(",")
+      cluster_member_ips = p("etcd.machines").map { |m| "#{client_protocol}://#{m}:4001" }.join(",")
       return cluster_member_ips
     end
   end
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
