set -e

PATCH_DIR=/var/vcap/jobs-src/cfdot/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p4 <<'PATCH'
--- a/jobs/cfdot/templates/setup.erb
+++ b/jobs/cfdot/templates/setup.erb
@@ -4,8 +4,8 @@ if ! echo $PATH | grep -q 'cfdot'; then
   export PATH=/var/vcap/packages/cfdot/bin:$PATH
 fi

-export BBS_URL=https://bbs.service.cf.internal:8889
-export LOCKET_API_LOCATION=locket.service.cf.internal:8891
+export BBS_URL=https://<%= p("cfdot.bbs.hostname") %>:8889
+export LOCKET_API_LOCATION=<%= p("cfdot.locket.hostname") %>:8891
 export CA_CERT_FILE=/var/vcap/jobs/cfdot/config/certs/cfdot/ca.crt
 export CLIENT_CERT_FILE=/var/vcap/jobs/cfdot/config/certs/cfdot/client.crt
 export CLIENT_KEY_FILE=/var/vcap/jobs/cfdot/config/certs/cfdot/client.keyPATCH
PATCH

touch "${SENTINEL}"

exit 0
