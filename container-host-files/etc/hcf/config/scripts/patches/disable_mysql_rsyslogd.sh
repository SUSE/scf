set -e

PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_setup_syslog_forwarder <<'PATCH' || true
--- pre-start-setup.erb.orig    2017-05-24 06:45:54.971512662 +0000
+++ pre-start-setup.erb 2017-05-24 06:47:42.908053512 +0000
@@ -37,7 +37,7 @@
 chown -R vcap:vcap "${HEALTHCHECK_LOG_DIR}"

 # Start syslog forwarding
-/var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $MARIADB_JOB_DIR/config
+#/var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $MARIADB_JOB_DIR/config

 # It is surprisingly hard to get the config file location passed in
 # on the command line to the mysql.server script. This is easier.
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_setup_syslog_forwarder}" | patch --force

touch "${SENTINEL}"

exit 0
