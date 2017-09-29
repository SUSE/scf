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

  patch -d "${PATCH_DIR}" -p 4 --force <<'PATCH'
diff --git a/jobs/etcd/templates/etcd_bosh_utils.sh.erb b/jobs/etcd/templates/etcd_bosh_utils.sh.erb
index 5711254..c28cbf5 100644
--- a/jobs/etcd/templates/etcd_bosh_utils.sh.erb
+++ b/jobs/etcd/templates/etcd_bosh_utils.sh.erb
@@ -57,7 +57,7 @@ DATA_DIR=${STORE_DIR}/etcd
     ips = nil
     if_p("etcd.machines") { |machines| ips = machines.map { |m| "http://#{m}:4001" } }
     unless ips
-      ips = link("etcd").instances.map { |i| "http://#{i.address}:4001" }
+      ips = link("etcd").instances.map { |i| "#{client_protocol}://#{i.address}:4001" }
     end
     ips
   end
PATCH
  
  touch "${SENTINEL}"
  fi

METRICS_PATCH_DIR="/var/vcap/jobs-src/etcd_metrics_server/templates"
METRICS_SENTINEL="${METRICS_PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${METRICS_SENTINEL}" ]; then

  patch -d "${METRICS_PATCH_DIR}" -p 0 --force <<'PATCH'
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
  
  touch "${METRICS_SENTINEL}"
fi

exit 0
