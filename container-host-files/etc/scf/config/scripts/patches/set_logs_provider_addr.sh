#! /usr/bin/env bash
set -e

# Break circular bosh-link between doppler and log-api

PATCH_DIR=/var/vcap/jobs-src/log-cache-nozzle/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -3,7 +3,6 @@
   certDir = "#{jobDir}/config/certs"
 
   lc = link("log-cache")
-  rlp = link('reverse_log_proxy')
 %>
 ---
 processes:
@@ -13,7 +12,7 @@ processes:
     HEALTH_PORT: "<%= p('health_port') %>"
 
     # Logs Provider
-    LOGS_PROVIDER_ADDR: "<%= "#{rlp.address}:#{rlp.p('reverse_log_proxy.egress.port')}" %>"
+    LOGS_PROVIDER_ADDR: "<%= "log-api-reverse-log-proxy.#{ENV['KUBERNETES_NAMESPACE']}.svc.#{ENV['KUBERNETES_CLUSTER_DOMAIN']}:8082" %>"
     LOGS_PROVIDER_CA_FILE_PATH:   "<%= "#{certDir}/logs_provider_ca.crt" %>"
     LOGS_PROVIDER_CERT_FILE_PATH: "<%= "#{certDir}/logs_provider.crt" %>"
     LOGS_PROVIDER_KEY_FILE_PATH:  "<%= "#{certDir}/logs_provider.key" %>"
PATCH

touch "${SENTINEL}"

exit 0
