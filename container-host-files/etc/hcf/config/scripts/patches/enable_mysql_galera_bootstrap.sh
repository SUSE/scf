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
+  User: '<%= p('hcf.monit.user') %>'
+  Password: '<%= p('hcf.monit.password') %>'
   Host: 'localhost'
-  Port: 2822
+  Port: <%= p('hcf.monit.port') %>
   MysqlStateFilePath: '/var/vcap/store/mysql/state.txt'
   ServiceName: 'mariadb_ctrl'
   BootstrapFilePath: '/var/vcap/jobs/mysql/bin/pre-start-execution'
PATCH

echo -e "${setup_patch_galera}" | patch --force

touch "${SENTINEL}"

exit 0
