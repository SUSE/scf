set -e

PATCH_DIR=/var/vcap/jobs-src/mysql/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

read -r -d '' setup_patch_galera <<'PATCH' || true
--- galera_healthcheck_config.yaml.erb.orig	2016-12-08 13:06:04.823906919 -0800
+++ galera_healthcheck_config.yaml.erb	2016-12-08 13:06:52.567908042 -0800
@@ -7,10 +7,10 @@
   Password: '<%= p('cf_mysql.mysql.galera_healthcheck.db_password') %>'
 # This is the config that bosh sets up by default for monit.
 Monit:
-  User: 'vcap'
-  Password: 'random-password'
+  User: 'admin'
+  Password: '<%= p('fissile.monit.password') %>'
   Host: 'localhost'
-  Port: 2822
+  Port: 2289
   MysqlStateFilePath: '/var/vcap/store/mysql/state.txt'
   ServiceName: 'mariadb_ctrl'
   BootstrapFilePath: '/var/vcap/jobs/mysql/bin/pre-start-execution'
PATCH

echo -e "${setup_patch_galera}" | patch --force

PATCH_DIR=$(dirname "$(ls /var/vcap/packages-src/*/bin/wsrep_sst_xtrabackup-v2)")

cd "$PATCH_DIR"

read -r -d '' setup_patch_wsrep_sst_xtrabackup <<'PATCH' || true
--- wsrep_sst_xtrabackup-v2.bak     2016-12-07 21:58:30.500216163 +0000
+++ wsrep_sst_xtrabackup-v2 2016-12-07 22:34:40.346273223 +0000
@@ -877,7 +877,7 @@
     if [ ! -r "${STATDIR}/${IST_FILE}" ]
     then

-        if [ ${DISABLE_SST:=0} -eq 1 ]
+        if [ ${DISABLE_SST:=0} -eq 1 ] && ! grep -q "uuid:    00000000-0000-0000-0000-000000000000" /var/vcap/store/mysql/grastate.dat
         then
             wsrep_log_error "##############################################################################"
             wsrep_log_error "SST disabled due to danger of data loss. Verify data and bootstrap the cluster"
PATCH

echo -e "${setup_patch_wsrep_sst_xtrabackup}" | patch --force

touch "${SENTINEL}"

exit 0
