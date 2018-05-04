#!/bin/sh
# This patch removes a timestamp check for /var/log/messages.
# For e.g., in nats or doppler, only limited logs will be recorded to /var/log/messages, and then this file is
# no longer updated. If /var/log/messages is outdated for more than 65 mins, there will be an alert
# named "timestamp failed".


PATCH_DIR="/etc/monit/monitrc.d"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"
cat <<'EOF' | patch
--- rsyslog.ori	2018-01-29 14:23:21.000000000 +0000
+++ rsyslog	2018-03-29 05:59:56.945312289 +0000
@@ -16,7 +16,6 @@

 check file rsyslog_file with path /var/log/messages
    group rsyslogd
-   if timestamp > 65 minutes then alert
    if failed permission 640  then unmonitor
    if failed uid "syslog"    then unmonitor
    if failed gid "syslog"    then unmonitor
EOF

echo "${PATCH_DIR}/${0##*/}" >> "${SENTINEL}"
exit 0