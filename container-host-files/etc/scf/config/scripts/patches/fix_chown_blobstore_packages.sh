set -e

PATCH_DIR="/var/vcap/jobs-src/blobstore/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

patch --force -p3 <<'PATCH'
diff --git jobs/blobstore/templates/pre-start.sh.erb jobs/blobstore/templates/pre-start.sh.erb
index 20b3140..1cf5a58 100644
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
@@ -18,12 +18,12 @@ function setup_blobstore_directories {
   mkdir -p $data_dir
   mkdir -p $data_tmp_dir

-  local dirs="$run_dir $log_dir $store_dir $store_tmp_dir $data_dir $data_tmp_dir $nginx_webdav_dir ${nginx_webdav_dir}/.."
-  local num_needing_chown=$(find $dirs -not -user vcap -or -not -group vcap | wc -l)
+  local dirs="$run_dir $log_dir $store_dir $store_tmp_dir $data_dir $data_tmp_dir $packages_dir"
+  local num_needing_chown=$(find -L $dirs -not -user vcap -or -not -group vcap | wc -l)

   if [ $num_needing_chown -gt 0 ]; then
     echo "chowning ${num_needing_chown} files to vcap:vcap"
-    find $dirs -not -user vcap -or -not -group vcap | xargs chown vcap:vcap
+    find -L $dirs -not -user vcap -or -not -group vcap | xargs chown vcap:vcap
   else
     echo "no chowning needed, all relevant files are vcap:vcap already"
   fi
PATCH

touch "${SENTINEL}"

exit 0
