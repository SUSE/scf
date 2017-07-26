set -e

PATCH_DIR="/var/vcap/jobs-src/cf-mysql-broker/templates"
PATCH_SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${PATCH_SENTINEL}" ]; then
    read -r -d '' setup_patch_broker <<'PATCH' || true
--- cf-mysql-broker_ctl.erb
+++ cf-mysql-broker_ctl.erb
@@ -35,8 +35,8 @@ case $1 in
     mkdir -p $LOG_DIR
     chown -R vcap:vcap $LOG_DIR

-    # Start syslog forwarding
-    /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $JOB_DIR/config
+    # Don't start syslog forwarding
+    # /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $JOB_DIR/config

     /var/vcap/packages/mariadb/bin/mysql \
       --defaults-file="${JOB_DIR}/config/mylogin.cnf" \
PATCH

    cd "$PATCH_DIR"

    echo -e "${setup_patch_broker}" | patch --force

    touch "${PATCH_SENTINEL}"
fi

exit 0
