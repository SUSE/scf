set -e

PATCH_DIR="/var/vcap/jobs-src/etcd/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_etcd_ctl <<'PATCH' || true
--- etcd_ctl.erb.orig	2017-05-17 13:37:05.054264713 -0700
+++ etcd_ctl.erb	2017-05-19 10:40:18.626839032 -0700
@@ -60,14 +60,19 @@
 
       create_cert_files
 
+      <% if_p("etcd.bootstrap_node") do |bootstrap_node| %>
       prior_member_list=""
-      for i in $(seq 5); do
+      <% if bootstrap_node != "#{name.gsub('_', '-')}-#{spec.index}" %>
+      # If this node is not the bootstrap node, wait until at least the
+      # bootstrap node comes up.
+      while [ -z "${prior_member_list}" ]; do
         prior_member_list=$(member_list)
-        if [ -n "${prior_member_list}" ]; then
-          break
-        fi
-        sleep 1
+        sleep 2
       done
+      <% end %>
+      <% end.else do %>
+      prior_member_list=$(member_list)
+      <% end %>
 
       if [ -z "${prior_member_list}" ]; then
         cluster_state=new
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_etcd_ctl}" | patch --force

touch "${SENTINEL}"

exit 0
