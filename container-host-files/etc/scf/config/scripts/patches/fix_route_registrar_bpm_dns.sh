#! /usr/bin/env bash

# This is a temporary patch needed to make kube-dns work for BPM-managed jobs.
# This will go away with the transition to the cf-operator, which will not require BPM anymore.

# This patch is bigger than for gorouter and routing_api because the
# ERB already touches on the unsafe.unrestricted_volumes (u.uv) based
# on health_checks for the routes to register. Had to move the code
# lower and make `u.uv` unconditional.

set -e

PATCH_DIR=/var/vcap/jobs-src/route_registrar/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

# Notes on "unsafe.unrestricted_volumes":
#
# - The mounts 1, 2, and 4 are required to make DNS work in the nested
#   container created by BPM for the job to run in.
#
# - The remainer are required to give the job access to the system
#   root certificates so that it actually can verify the certs given
#   to it by its partners.
#
# - This here is a bit more complicated than for gorouter and
#   routingapi (see their patch scripts) because we have to accomodate
#   the pre-existing code creating its own set of mounts for -
#   healthchecks.

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- bpm.yml.erb
+++ bpm.yml.erb
@@ -4,23 +4,26 @@ processes:
     args:
     - --configPath
     - /var/vcap/jobs/route_registrar/config/registrar_settings.json
-<%
-  paths = []
-  routes = p('route_registrar.routes')
-  routes.each do |route|
-    if route['health_check']
-      # valid path is /var/vcap/jobs/JOB
-      matched = /(^\/var\/vcap\/jobs\/[^\/]*)\/.*/.match(route['health_check']['script_path'])
-      if matched
-        paths << matched[1]
-      end
-    end
-  end
-
-  unless paths.empty? %>
     unsafe:
       unrestricted_volumes:
-<% end
+         - path: /etc/hostname
+         - path: /etc/hosts
+         - path: /etc/pki
+         - path: /etc/resolv.conf
+         - path: /etc/ssl
+         - path: /var/lib
+<% #     ^ Always mount the files needed for a working kube-dns, and certs
+   paths = []
+   routes = p('route_registrar.routes')
+   routes.each do |route|
+     if route['health_check']
+       # valid path is /var/vcap/jobs/JOB
+       matched = /(^\/var\/vcap\/jobs\/[^\/]*)\/.*/.match(route['health_check']['script_path'])
+       if matched
+         paths << matched[1]
+       end
+     end
+   end
    paths.each do |path| %>
          - path: <%= path %>
            allow_executions: true
PATCH

touch "${SENTINEL}"

exit 0
