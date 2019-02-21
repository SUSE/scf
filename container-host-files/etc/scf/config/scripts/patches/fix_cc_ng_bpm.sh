#! /usr/bin/env bash

# This is a temporary patch needed to make kube-dns work for BPM-managed jobs.
# This will go away with the transition to the cf-operator, which will not require BPM anymore.

set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb	2019-01-31 15:12:03.948058404 -0800
+++ bpm.yml.erb	2019-01-31 15:10:57.292215121 -0800
@@ -27,6 +27,15 @@
     "NEW_RELIC_ENV" => "#{p("cc.newrelic.environment_name")}",
     "NRCONFIG" => "/var/vcap/jobs/cloud_controller_ng/config/newrelic.yml",
     "RAILS_ENV" => "production",
+  },
+  "unsafe" => {
+    "unrestricted_volumes" => [
+      { "path" => "/etc/hostname" },
+      { "path" => "/etc/hosts" },
+      { "path" => "/etc/resolv.conf" },
+      { "path" => "/etc/ssl" },
+      { "path" => "/var/lib/ca-certificates" }
+    ]
   }
 }
 
@@ -55,12 +64,30 @@
   "executable" => "/var/vcap/packages/nginx/sbin/nginx",
   "args" => ["-c", "/var/vcap/jobs/cloud_controller_ng/config/nginx.conf"],
   "ephemeral_disk" => true,
+  "unsafe" => {
+    "unrestricted_volumes" => [
+      { "path" => "/etc/hostname" },
+      { "path" => "/etc/hosts" },
+      { "path" => "/etc/resolv.conf" },
+      { "path" => "/etc/ssl" },
+      { "path" => "/var/lib/ca-certificates" }
+    ]
+  }
 }
 mount_nfs_volume!(nginx_config)
 
 nginx_newrelic_plugin_config = {
   "name" => "nginx_newrelic_plugin",
   "executable" => "/var/vcap/jobs/cloud_controller_ng/bin/nginx_newrelic_plugin",
+  "unsafe" => {
+    "unrestricted_volumes" => [
+      { "path" => "/etc/hostname" },
+      { "path" => "/etc/hosts" },
+      { "path" => "/etc/resolv.conf" },
+      { "path" => "/etc/ssl" },
+      { "path" => "/var/lib/ca-certificates" }
+    ]
+  }
 }
 
 config = {
@@ -86,6 +113,15 @@
       "NEW_RELIC_DISPATCHER" => "delayed_job",
       "NRCONFIG" => "/var/vcap/jobs/cloud_controller_ng/config/newrelic.yml",
       "INDEX" => index
+    },
+    "unsafe" => {
+      "unrestricted_volumes" => [
+        { "path" => "/etc/hostname" },
+        { "path" => "/etc/hosts" },
+        { "path" => "/etc/resolv.conf" },
+        { "path" => "/etc/ssl" },
+        { "path" => "/var/lib/ca-certificates" }
+      ]
     }
   }
   mount_nfs_volume!(local_worker_config)
PATCH

# Notes on "unsafe.unrestricted_volumes":
#
# - The first three mounts are required to make DNS work in the nested
#   container created by BPM for the job to run in.
#
# - The remainder are required to give the job access to the system
#   root certificates so that it actually can verify the certs given
#   to it by its partners (like the router-registrar).

touch "${SENTINEL}"

exit 0
