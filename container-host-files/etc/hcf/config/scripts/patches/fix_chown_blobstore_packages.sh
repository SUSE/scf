set -e

PATCH_DIR="/var/vcap/jobs-src/blobstore/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_pre_start <<'PATCH' || true
--- pre-start.sh.erb
+++ pre-start.sh.erb
@@ -7,13 +7,13 @@ function setup_blobstore_directories {
   local log_dir=/var/vcap/sys/log/blobstore
   local data=/var/vcap/store/shared
   local tmp_dir=$data/tmp/uploads
-  local nginx_webdav_dir=/var/vcap/packages/nginx_webdav
+  local packages_dir=/var/vcap/packages
 
   mkdir -p $run_dir
   mkdir -p $log_dir
   mkdir -p $data
   mkdir -p $tmp_dir
-  chown -R vcap:vcap $run_dir $log_dir $data $tmp_dir $nginx_webdav_dir "${nginx_webdav_dir}/.."
+  chown -R vcap:vcap $run_dir $log_dir $data $tmp_dir $packages_dir
 }
 
 setup_blobstore_directories
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_pre_start}" | patch --force

touch "${SENTINEL}"

exit 0
