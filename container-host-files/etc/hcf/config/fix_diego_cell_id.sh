set -e

PATCH_DIR="/var/vcap/jobs-src/rep/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' cell_patch <<'PATCH' || true
--- rep_ctl.erb
+++ rep_ctl_patched.erb
@@ -108,7 +108,7 @@ case $1 in
       -listenAddr=<%= p("diego.rep.listen_addr") %> \
       <%= p("diego.rep.preloaded_rootfses").map { |rootfs| "-preloadedRootFS #{rootfs}" }.join(" ") %> \
       <%= p("diego.rep.rootfs_providers").map { |provider| "-rootFSProvider #{provider}" }.join(" ") %> \
-      -cellID=<%= spec.job.name %>-<%= spec.index %> \
+      -cellID=<%= spec.job.name %>-<%= spec.index %>-`hostname` \
       -zone=<%= p("diego.rep.zone") %> \
       -pollingInterval=<%= "#{p("diego.rep.polling_interval_in_seconds")}s" %> \
       -evacuationPollingInterval=<%= "#{p("diego.rep.evacuation_polling_interval_in_seconds")}s" %> \
PATCH

cd "$PATCH_DIR"

echo -e "${cell_patch}" | patch --force

touch "${SENTINEL}"

exit 0
