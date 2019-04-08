set -e

PATCH_DIR="/var/vcap/jobs-src/blobstore/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "$PATCH_DIR"

patch --force -p0 <<'PATCH'
--- pre-start.sh.erb	2019-01-31 10:32:11.714131780 -0800
+++ pre-start.sh.erb	2019-01-31 10:34:34.570302914 -0800
@@ -9,7 +9,7 @@
   local data_dir=/var/vcap/data/blobstore
   local store_tmp_dir=$store_dir/tmp/uploads
   local data_tmp_dir=$data_dir/tmp/uploads
-  local nginx_webdav_dir=/var/vcap/packages/nginx_webdav
+  local packages_dir=/var/vcap/packages
 
   mkdir -p $run_dir
   mkdir -p $log_dir
@@ -19,12 +19,12 @@
   mkdir -p $data_tmp_dir
 
   chown vcap:vcap $store_dir
-  local dirs="$run_dir $log_dir $store_tmp_dir $data_dir $data_tmp_dir $nginx_webdav_dir ${nginx_webdav_dir}/.."
-  local num_needing_chown=$(find $dirs -not -user vcap -or -not -group vcap | wc -l)
+  local dirs="$run_dir $log_dir $store_tmp_dir $data_dir $data_tmp_dir $packages_dir"
+  local num_needing_chown=$(find -L $dirs -not -user vcap -or -not -group vcap | wc -l)
 
   if [ $num_needing_chown -gt 0 ]; then
     echo "chowning ${num_needing_chown} files to vcap:vcap"
-    find $dirs -not -user vcap -or -not -group vcap | xargs chown vcap:vcap
+    find -L $dirs -not -user vcap -or -not -group vcap | grep -v "/var/vcap/packages/.src" | xargs chown vcap:vcap
   else
     echo "no chowning needed, all relevant files are vcap:vcap already"
   fi
PATCH

touch "${SENTINEL}"

exit 0
