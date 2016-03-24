#!/bin/sh
exec patch -p0 --force --forward <<"PATCH"
--- /var/vcap/jobs-src/etcd/templates/etcd_ctl.erb
+++ /var/vcap/jobs-src/etcd/templates/etcd_ctl.erb
@@ -30,7 +30,7 @@ case $1 in
 
     <% if p("etcd.require_ssl") %>
       set +e
-      host <%= p("etcd.dns_health_check_host") %>
+      host -t A <%= p("etcd.dns_health_check_host") %>
       if [[ "0" != "$?" ]]; then
         echo "DNS is not up"
         exit 1
PATCH
