set -e

# This patch is not meant to be upstreamed as vanilla CF uses canary nodes to
# bring up the first etcd node. Our k8s setup doesn't allow this right now, so
# we work around this by making the other nodes sleep until the bootstrap node
# is ready.

PATCH_DIR="/var/vcap/jobs-src/etcd/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

patch --force -p3 <<'PATCH'
diff --git jobs/etcd/templates/etcd_ctl.erb jobs/etcd/templates/etcd_ctl.erb
index 3c2e954..e0cea60 100644
--- jobs/etcd/templates/etcd_ctl.erb
+++ jobs/etcd/templates/etcd_ctl.erb
@@ -44,6 +44,14 @@ function start_etcdfab() {

     export GOMAXPROCS=$(nproc)

+    # SCF: If this is not the bootstrap node, wait for it to be up
+    if ! <%= spec.bootstrap.to_s %> ; then
+      while ! nslookup <%=name%>-0.<%=name%>-set ; do
+        sleep 2
+      done
+    fi
+    # SCF: END
+
     ${ETCDFAB_PACKAGE}/bin/etcdfab \
       start \
       --config-file ${JOB_DIR}/config/etcdfab.json \
PATCH

touch "${SENTINEL}"

exit 0
