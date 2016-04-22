set -e

PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -d '' setup_patch_mariadb_ctl_config <<PATCH || true
--- mariadb_ctl_config.yml.erb
+++ mariadb_ctl_config.yml_patched.erb
@@ -31,5 +31,5 @@ Manager:
   <% cluster_ips.each do |ip| %>
   - <%= ip %>
   <% end %>
-  MyIP: <%= spec.networks.send(p('network_name')).ip %>
+  MyIP: <%= p('cf_mysql.advertise_host') || spec.networks.send(p('network_name')).ip %>
   DatabaseStartupTimeout: <%= (p('cf_mysql.mysql.database_startup_timeout') * 0.8).round %>
PATCH

read -d '' setup_patch_my_cnf <<PATCH || true
--- my.cnf.erb
+++ my.cnf_patched.erb
@@ -28,7 +28,7 @@ nice      = 0
 wsrep_provider=/var/vcap/packages/mariadb/lib/plugin/libgalera_smm.so
 wsrep_provider_options="gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=TRUE"
 wsrep_cluster_address="gcomm://<%= cluster_ips.join(",") %>"
-wsrep_node_address='<%= spec.networks.send(p('network_name')).ip %>'
+wsrep_node_address='<%= p('cf_mysql.advertise_host') || spec.networks.send(p('network_name')).ip %>'
 wsrep_node_name='<%= name %>/<%= index %>'
 wsrep_cluster_name='cf-mariadb-galera-cluster'
 wsrep_sst_method=xtrabackup-v2
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_mariadb_ctl_config}" | patch --force
echo -e "${setup_patch_my_cnf}" | patch --force

touch "${SENTINEL}"

exit 0
