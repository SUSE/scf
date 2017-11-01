set -e

PRESTART_PATCH_DIR="/var/vcap/jobs-src/mysql/templates"
PRESTART_SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${PRESTART_SENTINEL}" ]; then
    patch -d "$PRESTART_PATCH_DIR" --force -p 3 <<'PATCH'
diff --git jobs/mysql/templates/pre-start-setup.erb jobs/mysql/templates/pre-start-setup.erb
index 3998d1ae..670deb2b 100644
--- jobs/mysql/templates/pre-start-setup.erb
+++ jobs/mysql/templates/pre-start-setup.erb
@@ -42,8 +42,10 @@ mkdir -p "${HEALTHCHECK_LOG_DIR}"
 chown -R vcap:vcap "${HEALTHCHECK_LOG_DIR}"
 
 <% if_p("syslog_aggregator.address", "syslog_aggregator.port", "syslog_aggregator.transport") do %>
+# SCF: Disable
 # Start syslog forwarding
-/var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $MARIADB_JOB_DIR/config
+# /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $MARIADB_JOB_DIR/config
+# SCF: END
 <% end.else do %>
 if [[ -e /etc/rsyslog.d/00-syslog_forwarder.conf ]]; then
   rm -f /etc/rsyslog.d/00-syslog_forwarder.conf
PATCH

    touch "${PRESTART_SENTINEL}"
fi

exit 0
