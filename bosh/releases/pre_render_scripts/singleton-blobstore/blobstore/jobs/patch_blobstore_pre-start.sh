#!/usr/bin/env bash

set -o errexit -o nounset

# Perform a faster chown when the blobstore starts.

target="/var/vcap/all-releases/jobs-src/capi/blobstore/templates/pre-start.sh.erb"

patch --binary --unified --verbose "${target}" <<'EOT'
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
+  local num_needing_chown="0"
 
   if [ $num_needing_chown -gt 0 ]; then
     echo "chowning ${num_needing_chown} files to vcap:vcap"
-    find $dirs -not -user vcap -or -not -group vcap | xargs chown vcap:vcap
+    echo "not chowning anything - it doesn't persist from the init container"
   else
     echo "no chowning needed, all relevant files are vcap:vcap already"
   fi
EOT
