set -e

PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_mariadb_ctl_config <<'PATCH' || true
--- mariadb_ctl_config.yml.erb	2016-03-15 22:17:31.000000000 +0000
+++ mariadb_ctl_config_patched.yml.erb	2016-04-23 02:17:12.000000000 +0000
@@ -58,5 +58,5 @@ Manager:
   <% cluster_ips.each do |ip| %>
   - <%= ip %>
   <% end %>
-  MyIP: <%= network_ip %>
+  MyIP: <%= p('cf_mysql.mysql.advertise_host') || network_ip %>
   ConnectionTimeout: 600
PATCH

read -r -d '' setup_patch_my_cnf <<'PATCH' || true
--- my.cnf.erb	2016-03-15 22:17:31.000000000 +0000
+++ my.cnf_patched.erb	2016-04-23 02:10:44.000000000 +0000
@@ -28,7 +28,8 @@ nice      = 0
 wsrep_provider=/var/vcap/packages/mariadb/lib/plugin/libgalera_smm.so
-wsrep_provider_options="gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=TRUE;pc.checksum=TRUE"
+wsrep_provider_options="gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=TRUE;pc.checksum=TRUE;ist.recv_addr=<%= network_ip %>:4568"
+wsrep_sst_receive_address='<%= network_ip %>:4444'
 wsrep_cluster_address="gcomm://<%= cluster_ips.join(",") %>"
-wsrep_node_address='<%= network_ip %>:<%= p('cf_mysql.mysql.galera_port') %>'
+wsrep_node_address='<%= p('cf_mysql.mysql.advertise_host') || spec.networks.send(p('network_name')).ip %>:<%= p('cf_mysql.mysql.galera_port') %>'
 wsrep_node_name='<%= name %>/<%= index %>'
 wsrep_cluster_name='cf-mariadb-galera-cluster'
 wsrep_sst_method=xtrabackup-v2
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_mariadb_ctl_config}" | patch --force
echo -e "${setup_patch_my_cnf}" | patch --force

touch "${SENTINEL}"

exit 0
