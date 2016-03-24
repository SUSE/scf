set -e

SENTINEL="/var/vcap/jobs-src/cloud_controller_ng/templates/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

# *********************************************
# cloud_controller_ng fix
# *********************************************
read -d '' setup_patch <<PATCH || true
--- cloud_controller_api.yml.erb	Sun Feb 14 14:03:50 2016
+++ cloud_controller_api.yml.erb.patched	Thu Feb 18 07:23:42 2016
@@ -21,7 +21,7 @@
 #Actually NGX host and port
 local_route: <%= discover_external_ip %>
 external_port: <%= p("cc.external_port") %>
-internal_service_hostname: cloud-controller-ng.service.cf.internal
+internal_service_hostname: <%= p("cc.internal_service_hostname") %>

 pid_filename: /var/vcap/sys/run/cloud_controller_ng/cloud_controller_ng.pid
 newrelic_enabled: <%= !!properties.cc.newrelic.license_key || p("cc.development_mode") %>
PATCH

job_dir="/var/vcap/jobs-src/cloud_controller_ng/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir
  echo -e "${setup_patch}" | patch --force
fi

# *********************************************
# cloud_controller_worker fix
# *********************************************
read -d '' setup_patch <<PATCH || true
--- cloud_controller_worker.yml.erb	Sun Feb 14 14:03:50 2016
+++ cloud_controller_worker.yml.erb.patched	Thu Feb 18 07:24:05 2016
@@ -21,7 +21,7 @@
 #Actually NGX host and port
 local_route: <%= discover_external_ip %>
 external_port: <%= p("cc.external_port") %>
-internal_service_hostname: cloud-controller-ng.service.cf.internal
+internal_service_hostname: <%= p("cc.internal_service_hostname") %>

 pid_filename: /this/isnt/used/by/the/worker
 newrelic_enabled: <%= !!properties.cc.newrelic.license_key %>
PATCH

job_dir="/var/vcap/jobs-src/cloud_controller_worker/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir
  echo -e "${setup_patch}" | patch --force
fi

# *********************************************
# cloud_controller_clock fix
# *********************************************
read -d '' setup_patch <<PATCH || true
--- cloud_controller_clock.yml.erb	Sun Feb 14 14:03:50 2016
+++ cloud_controller_clock.yml.erb.patched	Thu Feb 18 07:23:54 2016
@@ -21,7 +21,7 @@
 #Actually NGX host and port
 local_route: <%= discover_external_ip %>
 external_port: <%= p("cc.external_port") %>
-internal_service_hostname: cloud-controller-ng.service.cf.internal
+internal_service_hostname: <%= p("cc.internal_service_hostname") %>

 pid_filename: /var/vcap/sys/run/cloud_controller_clock/cloud_controller_ng.pid
 newrelic_enabled: false
PATCH

job_dir="/var/vcap/jobs-src/cloud_controller_clock/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir
  echo -e "${setup_patch}" | patch --force
fi

touch "${SENTINEL}"

exit 0
