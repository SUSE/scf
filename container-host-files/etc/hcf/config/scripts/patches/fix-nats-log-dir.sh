set -e

SENTINEL="/var/vcap/jobs-src/patch.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' nats_patch <<'PATCH' || true
diff --git a/jobs/nats/templates/pre-start.erb b/jobs/nats/templates/pre-start.erb
index 0095e8f..8f046bb 100644
--- a/jobs/nats/templates/pre-start.erb
+++ b/jobs/nats/templates/pre-start.erb
@@ -2,6 +2,8 @@
 set -exu

 LOG_DIR=/var/vcap/sys/log/nats
+mkdir -p $LOG_DIR
+chown -R vcap:vcap $LOG_DIR

 # Avoid Neighbour table overflow
 # gc_thresh2 and gc_thresh3 are the soft and hard limits for arp table gc
@@ -19,6 +21,3 @@ fi
 if [ -f /var/vcap/sys/log/nats_ctl.err.log ]; then
   mv /var/vcap/sys/log/nats_ctl.err.log $LOG_DIR/nats_ctl.err.log
 fi
-
-mkdir -p $LOG_DIR
-chown -R vcap:vcap $LOG_DIR
PATCH

read -r -d '' nats_fwd_patch <<'PATCH' || true
diff --git a/jobs/nats_stream_forwarder/templates/pre-start.erb b/jobs/nats_stream_forwarder/templates/pre-start.erb
index 0ef3d3c..c649e45 100644
--- a/jobs/nats_stream_forwarder/templates/pre-start.erb
+++ b/jobs/nats_stream_forwarder/templates/pre-start.erb
@@ -5,6 +5,9 @@ set -exu
 # the migration from root user to vcap user
 LOG_DIR=/var/vcap/sys/log/nats_stream_forwarder

+mkdir -p $LOG_DIR
+chown -R vcap:vcap $LOG_DIR
+
 if [ -f /var/vcap/sys/log/nats_stream_forwarder_ctl.log ]; then
   mv /var/vcap/sys/log/nats_stream_forwarder_ctl.log $LOG_DIR/nats_stream_forwarder_ctl.log
 fi
@@ -12,6 +15,3 @@ fi
 if [ -f /var/vcap/sys/log/nats_stream_forwarder_ctl.err.log ]; then
   mv /var/vcap/sys/log/nats_stream_forwarder_ctl.err.log $LOG_DIR/nats_stream_forwarder_ctl.err.log
 fi
-
-mkdir -p $LOG_DIR
-chown -R vcap:vcap $LOG_DIR
PATCH

cd /var/vcap/jobs-src/nats/templates
echo -e "${nats_patch}" | patch --force
cd /var/vcap/jobs-src/nats_stream_forwarder/templates
echo -e "${nats_fwd_patch}" | patch --force

touch "${SENTINEL}"

exit 0
