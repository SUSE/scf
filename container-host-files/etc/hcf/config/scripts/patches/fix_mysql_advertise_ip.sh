set -e

PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_my_cnf <<'PATCH' || true
--- my.cnf.erb	2017-05-17 13:19:47.871198692 -0700
+++ my.cnf_patched.erb	2017-05-19 09:29:03.369987394 -0700
@@ -47,7 +47,8 @@
 # GALERA options:
 wsrep_on=ON
 wsrep_provider=/var/vcap/packages/mariadb/lib/plugin/libgalera_smm.so
-wsrep_provider_options="gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=TRUE;pc.checksum=TRUE"
+wsrep_provider_options="gcache.size=<%= p('cf_mysql.mysql.gcache_size') %>M;pc.recovery=TRUE;pc.checksum=TRUE;ist.recv_addr=<%= node_host %>:4568"
+wsrep_sst_receive_address='<%= node_host %>:4444'
 wsrep_cluster_address="gcomm://<%= cluster_ips.join(",") %>"
 wsrep_node_address='<%= node_host %>:<%= p('cf_mysql.mysql.galera_port') %>'
 wsrep_node_name='<%= name %>/<%= index %>'
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_my_cnf}" | patch --force

touch "${SENTINEL}"

exit 0
