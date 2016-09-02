set -e

PATCH_DIR="/var/vcap/jobs-src/etcd/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_etcd_ctl <<'PATCH' || true
--- etcd_ctl.erb.orig
+++ etcd_ctl.erb
@@ -55,7 +55,19 @@ function main() {

       create_cert_files

+      <% if_p("etcd.bootstrap_node") do |bootstrap_node| %>
+      prior_member_list=""
+      <% if bootstrap_node != "#{name.gsub('_', '-')}-#{spec.index}" %>
+      # If this node is not the bootstrap node, wait until at least the
+      # bootstrap node comes up.
+      while [ -z "${prior_member_list}" ]; do
+        prior_member_list=$(member_list)
+        sleep 2
+      done
+      <% end %>
+      <% end.else do %>
       prior_member_list=$(member_list)
+      <% end %>

       if [ -z "${prior_member_list}" ]; then
         cluster_state=new
@@ -72,6 +84,11 @@ function main() {
         my_id=$(extract_my_id "${prior_member_list}")
         if [ -z "${my_id}" ]; then
           member_add
+        fi
+
+        # If the node was just added, or the node has been added but isn't started,
+        # ensure it's in the cluster list
+        if [[ "${cluster}" != *"${this_node}"* ]]; then
           cluster="${cluster},${this_node}"
         fi
       fi
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_etcd_ctl}" | patch --force

touch "${SENTINEL}"

exit 0
