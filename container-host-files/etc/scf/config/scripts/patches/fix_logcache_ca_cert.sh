#! /usr/bin/env bash
set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- logcache_tls_ca.crt.erb
+++ logcache_tls_ca.crt.erb
@@ -1,5 +1,5 @@
 <%=
-  result = ''
+  result = p('cc.mutual_tls.ca_cert')
   if_link("log-cache") do |log_cache|
     result = log_cache.p('tls.ca_cert')
   end
PATCH

touch "${SENTINEL}"

exit 0
