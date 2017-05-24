set -e

PATCH_DIR="/var/vcap/jobs-src/proxy/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_setup_syslog_forwarder <<'PATCH' || true
--- switchboard_ctl.erb.orig    2017-05-24 07:10:23.950575489 +0000
+++ switchboard_ctl.erb 2017-05-24 07:10:42.463587167 +0000
@@ -27,7 +27,7 @@
     cd $package_dir

     # Start syslog forwarding
-    /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $job_dir/config
+#   /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh $job_dir/config

     su - vcap -c -o pipefail "$package_dir/bin/switchboard \
       -configPath=$job_dir/config/switchboard.yml \
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_setup_syslog_forwarder}" | patch --force

touch "${SENTINEL}"

exit 0
