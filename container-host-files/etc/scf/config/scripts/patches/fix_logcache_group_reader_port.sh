set -e

PATCH_DIR=/var/vcap/jobs-src/log-cache-group-reader/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- environment.sh.erb	2019-02-05 12:54:23.389389420 -0800
+++ environment.sh.erb	2019-02-05 12:54:46.061362773 -0800
@@ -1,4 +1,4 @@
-export ADDR="<%= ":#{p('port')}" %>"
+export ADDR=":8086"
 export HEALTH_ADDR="<%= "#{p('health_addr')}" %>"
 export LOG_CACHE_ADDR="<%= "#{link('log-cache').address}:#{link('log-cache').p('port')}" %>"
 export CA_PATH="/var/vcap/jobs/log-cache-group-reader/config/certs/ca.crt"
PATCH

touch "${SENTINEL}"

exit 0
