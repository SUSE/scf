set -e

PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

patch --force -p4 <<'PATCH'
diff --git a/jobs/mysql/templates/my.cnf.erb b/jobs/mysql/templates/my.cnf.erb
index 514acdd5..80bb6b0e 100644
--- a/jobs/mysql/templates/my.cnf.erb
+++ b/jobs/mysql/templates/my.cnf.erb
@@ -58,13 +58,14 @@ nice                            = 0
 # GALERA options:
 wsrep_on                        = ON
 wsrep_provider                  = /var/vcap/packages/mariadb/lib/plugin/libgalera_smm.so
-wsrep_provider_options          = "gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=FALSE;pc.checksum=TRUE"
+wsrep_provider_options          = "gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=FALSE;pc.checksum=TRUE;ist.recv_addr=<%= discover_external_ip %>:4568"
 wsrep_cluster_address           = gcomm://<%= cluster_ips.join(",") %>
 wsrep_node_address              = <%= node_host %>:<%= p('cf_mysql.mysql.galera_port') %>
 wsrep_node_name                 = <%= name %>/<%= index %>
 wsrep_cluster_name              = <%= p('cf_mysql.mysql.cluster_name') %>
 wsrep_sst_method                = xtrabackup-v2
 wsrep_sst_auth                  = <%= p('cf_mysql.mysql.admin_username')%>:<%= p('cf_mysql.mysql.admin_password') %>
+wsrep_sst_receive_address       = '<%= discover_external_ip %>:4444'
 wsrep_max_ws_rows               = <%= p('cf_mysql.mysql.wsrep_max_ws_rows') %>
 wsrep_max_ws_size               = <%= p('cf_mysql.mysql.wsrep_max_ws_size') %>
 wsrep_load_data_splitting       = ON
PATCH

touch "${SENTINEL}"

exit 0
