#!/bin/sh
exec patch -p0 --force --forward <<"PATCH"
--- /var/vcap/jobs-src/consul_agent/templates/agent_ctl.sh.erb
+++ /var/vcap/jobs-src/consul_agent/templates/agent_ctl.sh.erb
@@ -39,7 +39,7 @@ function setup_resolvconf() {
   local resolvconf_file
   resolvconf_file=/etc/resolvconf/resolv.conf.d/head
 
-  if ! grep -q 127.0.0.1 "${resolvconf_file}"; then
+  if ! grep -qE '\b127.0.0.1\b' "${resolvconf_file}"; then
 	  if [[ "$(stat -c "%s" "${resolvconf_file}")" = "0" ]]; then
 		  echo 'nameserver 127.0.0.1' > "${resolvconf_file}"
 	  else
@@ -96,7 +96,7 @@ function start() {
   export GOMAXPROCS
 
   local nameservers
-  nameservers=("$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -v 127.0.0.1)")
+  nameservers=("$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -vE '\b127.0.0.1\b')")
 
   local recursors
   recursors=""
PATCH
