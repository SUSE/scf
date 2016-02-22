set -e

# Note that for some reason you need 4 backslashes to get one in this heredoc



read -d '' consul_patch <<"PATCH" || true
--- agent_ctl.sh.erb    2016-02-14 22:04:12.000000000 +0000
+++ agent_ctl.sh.erb.patched    2016-02-21 14:39:16.832971103 +0000
@@ -138,7 +138,13 @@
     synced=true
     if [ $expected -gt 0 ]; then
       synced=false
-      consul_server_ips="<%=p("consul.agent.servers.lan").join('\\\\\\\\|')%>"
+
+      # Normalize consul addresses to IPs so we can later look them up
+      consul_server_ips="<%=
+        p("consul.agent.servers.lan").map {|server|
+          `getent ahostsv4 #{server} | awk '{ print $1 ; exit }'`.strip
+        }.join('\\\\\\\\|')%>"
+
       for i in $(seq <%= p("consul.agent.sync_timeout_in_seconds") %>); do
         echo "$(date)" "Waiting to have joined one of: ${consul_join}"
         if $PKG/bin/consul members -status=alive | grep "${consul_server_ips}"; then
PATCH

cd /var/vcap/jobs-src/consul_agent/templates/
echo -e "${consul_patch}" | patch

exit 0
