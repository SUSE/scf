set -e

PATCH_DIR=/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/jobs/runtime
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p3 <<'PATCH'
diff --git app/jobs/runtime/buildpack_installer.rb app/jobs/runtime/buildpack_installer.rb
index cfac8f1c6..9432ad95f 100644
--- app/jobs/runtime/buildpack_installer.rb
+++ app/jobs/runtime/buildpack_installer.rb
@@ -16,7 +16,11 @@ module VCAP::CloudController

           buildpack = Buildpack.find(name: name)
           if buildpack.nil?
-            buildpack = Buildpack.create(name: name)
+            buildpacks_lock = Locking[name: 'buildpacks']
+            buildpacks_lock.db.transaction do
+              buildpacks_lock.lock!
+              buildpack = Buildpack.create(name: name)
+            end
             created = true
           elsif buildpack.locked
             logger.info "Buildpack #{name} locked, not updated"
PATCH

touch "${SENTINEL}"

exit 0
