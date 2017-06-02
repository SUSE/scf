set -e

SWITCHBOARD_PATCH_DIR="/var/vcap/jobs-src/proxy/templates"
SWITCHBOARD_SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${SWITCHBOARD_SENTINEL}" ]; then
    read -r -d '' setup_patch_switchboard <<'PATCH' || true
--- switchboard_ctl.erb.orig	2017-05-17 13:19:47.871198692 -0700
+++ switchboard_ctl.erb	2017-05-26 09:44:43.955858973 -0700
@@ -26,8 +26,8 @@
 
     cd $package_dir
 
-    # Start syslog forwarding
-    /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $job_dir/config
+    # Don't start syslog forwarding
+    # /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $job_dir/config
 
     su - vcap -c -o pipefail "$package_dir/bin/switchboard \
       -configPath=$job_dir/config/switchboard.yml \
PATCH

    cd "$SWITCHBOARD_PATCH_DIR"

    echo -e "${setup_patch_switchboard}" | patch --force

    touch "${SWITCHBOARD_SENTINEL}"
fi

exit 0
