set -e

PATCH_DIR="/var/vcap/packages/syslog_aggregator"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' disable_mysql_syslog_forwarder <<'PATCH' || true
--- setup_syslog_forwarder.sh	2017-05-15 12:23:58.000000000 +0000
+++ setup_syslog_forwarder.sh.new	2017-05-29 10:29:29.758813907 +0000
@@ -11,9 +11,9 @@
 CONFIG_DIR=$1
 
 # Place to spool logs if the upstream server is down
-mkdir -p /var/vcap/sys/rsyslog/buffered
-chown -R vcap:vcap /var/vcap/sys/rsyslog/buffered
+# mkdir -p /var/vcap/sys/rsyslog/buffered
+# chown -R vcap:vcap /var/vcap/sys/rsyslog/buffered
 
-cp $CONFIG_DIR/syslog_forwarder.conf /etc/rsyslog.d/00-syslog_forwarder.conf
+# cp $CONFIG_DIR/syslog_forwarder.conf /etc/rsyslog.d/00-syslog_forwarder.conf
 
-/usr/sbin/service rsyslog restart
+# /usr/sbin/service rsyslog restart
PATCH

cd "$PATCH_DIR"

echo -e "${disable_mysql_syslog_forwarder}" | patch --force

touch "${SENTINEL}"

exit 0
