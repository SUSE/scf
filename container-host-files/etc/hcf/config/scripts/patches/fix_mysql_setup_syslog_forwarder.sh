set -e

PRESTART_PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
PRESTART_SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${PRESTART_SENTINEL}" ]; then
    read -r -d '' setup_patch_prestart <<'PATCH' || true
--- pre-start-setup.erb.orig	2017-05-17 13:19:47.871198692 -0700
+++ pre-start-setup.erb	2017-05-26 09:55:00.267200002 -0700
@@ -36,8 +36,8 @@
 mkdir -p "${HEALTHCHECK_LOG_DIR}"
 chown -R vcap:vcap "${HEALTHCHECK_LOG_DIR}"
 
-# Start syslog forwarding
-/var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $MARIADB_JOB_DIR/config
+# Don't start syslog forwarding
+# /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $MARIADB_JOB_DIR/config
 
 # It is surprisingly hard to get the config file location passed in
 # on the command line to the mysql.server script. This is easier.
PATCH

    cd "$PRESTART_PATCH_DIR"

    echo -e "${setup_patch_prestart}" | patch --force

    touch "${PRESTART_SENTINEL}"
fi

exit 0
