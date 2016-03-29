set -e

SENTINEL="/var/vcap/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

# *********************************************
# bbs fix
# *********************************************
job_dir="/var/vcap/jobs-src/bbs/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  patch -t <<"PATCH"
--- bbs_ctl.erb
+++ bbs_ctl.erb
@@ -78,7 +78,7 @@ case $1 in
 
     exec chpst -u vcap:vcap /var/vcap/packages/bbs/bin/bbs ${etcd_sec_flags} ${bbs_sec_flags} \
       -activeKeyLabel='<%= p("diego.bbs.active_key_label") %>' \
-      -advertiseURL=${ad_url_scheme}<%="://#{name.gsub('_', '-')}-#{spec.index}.bbs.service.cf.internal:#{p("diego.bbs.listen_addr").split(':')[1]}" %> \
+      -advertiseURL=${ad_url_scheme}<%="://#{name.gsub('_', '-')}-#{spec.index}.#{p("diego.bbs.ad_address_suffix")}:#{p("diego.bbs.listen_addr").split(':')[1]}" %> \
       -auctioneerAddress=<%= p("diego.bbs.auctioneer.api_url") %> \
       -consulCluster=http://127.0.0.1:<%= p("diego.bbs.consul_agent_port") %> \
       -debugAddr=<%= p("diego.bbs.debug_addr") %> \
PATCH
fi

touch "${SENTINEL}"

exit 0
