set -e

PATCH_DIR="/var/vcap/jobs-src/rep/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_rep_json <<'PATCH' || true
--- a/jobs/rep/templates/rep.json.erb
+++ b/jobs/rep/templates/rep.json.erb
@@ -16,7 +16,7 @@ config = {
  "supported_providers" => p("diego.rep.rootfs_providers"),
  "placement_tags" => p("diego.rep.placement_tags"),
  "optional_placement_tags" => p("diego.rep.optional_placement_tags"),
- "cell_id" => "#{spec.job.name}-#{spec.index}-#{spec.id}",
+ "cell_id" => p("diego.rep.cell_id", "#{spec.job.name}-#{spec.index}-#{spec.id}"),
  "zone" => spec.az || p("diego.rep.zone"),
  "polling_interval" => "#{p("diego.rep.polling_interval_in_seconds")}s",
  "evacuation_polling_interval" => "#{p("diego.rep.evacuation_polling_interval_in_seconds")}s",
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_rep_json}" | patch --force

  touch "${SENTINEL}"
fi

exit 0
