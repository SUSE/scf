set -e

SWITCHBOARD_PATCH_DIR="/var/vcap/jobs-src/proxy/templates"
SWITCHBOARD_SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${SWITCHBOARD_SENTINEL}" ]; then
    patch -d "${SWITCHBOARD_PATCH_DIR}" --force -p 3 <<'PATCH'
diff --git jobs/proxy/templates/switchboard_ctl.erb jobs/proxy/templates/switchboard_ctl.erb
index 7a03417d..821fbf11 100644
--- jobs/proxy/templates/switchboard_ctl.erb
+++ jobs/proxy/templates/switchboard_ctl.erb
@@ -27,8 +27,10 @@ case $1 in
     cd $package_dir
 
     <% if_p("syslog_aggregator.address", "syslog_aggregator.port", "syslog_aggregator.transport") do %>
+    # SCF: Disable
     # Start syslog forwarding
-    /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $job_dir/config
+    # /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $job_dir/config
+    # SCF: END
     <% end %>
 
     su - vcap -c -o pipefail "$package_dir/bin/switchboard \
PATCH

    touch "${SWITCHBOARD_SENTINEL}"
fi

exit 0
