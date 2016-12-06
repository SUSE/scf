set -e

PATCH_DIR="/var/vcap/jobs-src/rep/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_rep_as_vcap <<'PATCH' || true
--- rep_as_vcap.erb.orig
+++ rep_as_vcap.erb
@@ -71,7 +71,7 @@ exec /var/vcap/packages/rep/bin/rep ${bbs_sec_flags} ${rep_sec_flags} \
   <%= p("diego.rep.rootfs_providers").map { |provider| "-rootFSProvider #{provider}" }.join(" ") %> \
   <%= p("diego.rep.placement_tags").map { |tag| "-placementTag #{Shellwords.shellescape(tag)}" }.join(" ") %> \
   <%= p("diego.rep.optional_placement_tags").map { |tag| "-optionalPlacementTag #{Shellwords.shellescape(tag)}" }.join(" ") %> \
-  -cellID=<%= spec.job.name %>-<%= spec.index %>-<%= spec.id %> \
+  -cellID=<%= p("diego.rep.cell_id", "#{spec.job.name}-#{spec.index}-#{spec.id}") %> \
   -zone="${zone}" \
   -pollingInterval=<%= "#{p("diego.rep.polling_interval_in_seconds")}s" %> \
   -evacuationPollingInterval=<%= "#{p("diego.rep.evacuation_polling_interval_in_seconds")}s" %> \
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_rep_as_vcap}" | patch --force

  touch "${SENTINEL}"
fi

exit 0
