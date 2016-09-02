#!/bin/sh
# cloud_controller_ng: make the number of droplets to keep configurable
# https://github.com/cloudfoundry/cloud_controller_ng/pull/627

set -o errexit

cd /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/jobs/runtime

if test -f droplet_upload.rb.sentinel ; then
    # Already patched
    exit 0
fi

patch -p0 --force <<'PATCH'
--- droplet_upload.rb
+++ droplet_upload.rb
@@ -4,9 +4,10 @@ module VCAP::CloudController
       class DropletUpload < VCAP::CloudController::Jobs::CCJob
         attr_reader :local_path, :app_id
 
-        def initialize(local_path, app_id)
+        def initialize(local_path, app_id, config=Config.config)
           @local_path = local_path
           @app_id = app_id
+          @droplets_storage_count = config[:droplets][:max_staged_droplets_stored] || 2
         end
 
         def perform
@@ -17,7 +18,7 @@ module VCAP::CloudController
 
           if app
             blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
-            CloudController::DropletUploader.new(app, blobstore).upload(local_path)
+            CloudController::DropletUploader.new(app, blobstore).upload(local_path, @droplets_storage_count)
           end
 
           FileUtils.rm_f(local_path)
PATCH

touch droplet_upload.rb.sentinel
