set -e

PATCH_DIR="/var/vcap/jobs-src/blobstore/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

patch --force -p3 <<'PATCH'
diff --git jobs/blobstore/templates/pre-start.sh.erb jobs/blobstore/templates/pre-start.sh.erb
index 431b2dc..35bab6c 100644
--- jobs/blobstore/templates/pre-start.sh.erb
+++ jobs/blobstore/templates/pre-start.sh.erb
@@ -9,7 +9,7 @@ function setup_blobstore_directories {
   local data_dir=/var/vcap/data/blobstore
   local store_tmp_dir=$store_dir/tmp/uploads
   local data_tmp_dir=$data_dir/tmp/uploads
-  local nginx_webdav_dir=/var/vcap/packages/nginx_webdav
+  local packages_dir=/var/vcap/packages
 
   mkdir -p $run_dir
   mkdir -p $log_dir
@@ -17,7 +17,7 @@ function setup_blobstore_directories {
   mkdir -p $store_tmp_dir
   mkdir -p $data_dir
   mkdir -p $data_tmp_dir
-  chown -R vcap:vcap $run_dir $log_dir $store_dir $store_tmp_dir $data_dir $data_tmp_dir $nginx_webdav_dir "${nginx_webdav_dir}/.."
+  chown -R -L vcap:vcap $run_dir $log_dir $store_dir $store_tmp_dir $data_dir $data_tmp_dir $packages_dir
 }
 
 setup_blobstore_directories
PATCH

touch "${SENTINEL}"

exit 0
