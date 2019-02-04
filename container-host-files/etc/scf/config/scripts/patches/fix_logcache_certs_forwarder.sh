set -e

PATCH_DIR=/var/vcap/jobs-src/log-cache-expvar-forwarder/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- ca.crt.erb	2019-02-12 14:32:28.469522442 -0800
+++ ca.crt.erb	2019-02-12 14:32:30.637520728 -0800
@@ -1 +1 @@
-<%= link('log-cache').p('tls.ca_cert') %>
+<%= p('tls.ca_cert') %>
--- log_cache.crt.erb	2019-02-12 14:33:19.133482512 -0800
+++ log_cache.crt.erb	2019-02-12 14:33:21.653480531 -0800
@@ -1 +1 @@
-<%= link('log-cache').p('tls.cert') %>
+<%= p('tls.cert') %>
--- log_cache.key.erb	2019-02-12 14:33:19.137482508 -0800
+++ log_cache.key.erb	2019-02-12 14:33:34.293470609 -0800
@@ -1 +1 @@
-<%= link('log-cache').p('tls.key') %>
+<%= p('tls.key') %>
PATCH

touch "${SENTINEL}"

exit 0
