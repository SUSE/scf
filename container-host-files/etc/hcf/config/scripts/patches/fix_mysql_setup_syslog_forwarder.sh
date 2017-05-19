set -e

PATCH_DIR="/var/vcap/packages/syslog_aggregator"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_setup_syslog_forwarder <<'PATCH' || true
--- setup_syslog_forwarder.sh.orig	2017-05-17 13:19:47.875198688 -0700
+++ setup_syslog_forwarder.sh	2017-05-19 14:14:06.723986301 -0700
@@ -16,4 +16,4 @@
 
 cp $CONFIG_DIR/syslog_forwarder.conf /etc/rsyslog.d/00-syslog_forwarder.conf
 
-/usr/sbin/service rsyslog reload
+/usr/sbin/service rsyslog force-reload
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_setup_syslog_forwarder}" | patch --force

touch "${SENTINEL}"

exit 0
