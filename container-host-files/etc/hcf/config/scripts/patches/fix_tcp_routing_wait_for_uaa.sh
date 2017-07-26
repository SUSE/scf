set -e

PATCH_DIR="/var/vcap/jobs-src/tcp_router/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_pre_start <<'PATCH' || true
--- pre-start	2017-07-24 16:32:40.000000000 -0700
+++ pre-start.new	2017-07-24 15:51:13.000000000 -0700
@@ -24,4 +24,45 @@
 setcap_haproxy
 chown -R vcap:vcap "${CONFIG_DIR}"
 
+# Report progress to the user; use as printf
+status() {
+    local fmt="${1}"
+    shift
+    printf "\n%b${fmt}%b\n" "\033[0;32m" "$@" "\033[0m"
+}
+
+# Report problem to the user; use as printf
+trouble() {
+    local fmt="${1}"
+    shift
+    printf "\n%b${fmt}%b\n" "\033[0;31m" "$@" "\033[0m"
+}
+
+# helper function to retry a command several times, with a delay between trials
+# usage: retry <max-tries> <delay> <command>...
+function retry () {
+    max=${1}
+    delay=${2}
+    i=0
+    shift 2
+
+    while test ${i} -lt ${max} ; do
+        printf "Trying: %s\n" "$*"
+        if "$@" ; then
+            status ' SUCCESS'
+            break
+        fi
+        trouble '  FAILED'
+        status "Waiting ${delay} ..."
+        sleep "${delay}"
+        i="$(expr ${i} + 1)"
+    done
+}
+
+CURL_SKIP="<%= properties.skip_ssl_validation ? '--insecure' : '' %>"
+UAA_ENDPOINT="https://<%= p('uaa.token_endpoint') %>:<%= p('uaa.tls_port') %>"
+
+status "Waiting for UAA ..."
+retry 240 30s curl --connect-timeout 5 --fail --header 'Accept: application/json' $UAA_ENDPOINT/info
+
 exit 0
PATCH

cd "$PATCH_DIR"

echo "${setup_pre_start}" | patch --force

touch "${SENTINEL}"

exit 0
