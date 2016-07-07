set -e

PATCH_DIR="/var/vcap/jobs-src/cloud_controller_ng/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_cloud_controller_api_worker_ctl_config <<'PATCH' || true
--- cloud_controller_api_worker_ctl.erb
+++ cloud_controller_api_worker_ctl_patched.erb
@@ -40,6 +40,20 @@ case $1 in
 
     wait_for_blobstore
 
+    cd $CC_PACKAGE_DIR/cloud_controller_ng
+
+    <% if spec.index.to_i == 0 %>
+    # Run the buildpack install only on the first CC Worker launch
+    if [ $INDEX == 1 ]; then
+      bundle exec rake buildpacks:install
+
+      if [ $? != 0 ]; then
+        echo "Buildpacks installation failed"
+        exit 1
+      fi
+    fi
+    <% end %>
+
     cd "${CC_PACKAGE_DIR}/cloud_controller_ng"
     exec bundle exec rake "jobs:local[cc_api_worker.<%= spec.job.name %>.<%= spec.index %>.${INDEX}]"
   ;;
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_cloud_controller_api_worker_ctl_config}" | patch --force

touch "${SENTINEL}"

exit 0
