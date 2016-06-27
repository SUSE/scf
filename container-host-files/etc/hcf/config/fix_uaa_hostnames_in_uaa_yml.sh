#!/bin/sh

# This patch is from HCF-733
# When using erb to emit YAML, put the whitespace inside the <%...%> part
# to ensure full control of emitted whitespace.

set -o errexit -o nounset

PATCH_DIR="/var/vcap/jobs-src/uaa/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "${PATCH_DIR}"

patch -p0 --force <<'EOF'
diff --git a/jobs/uaa/templates/uaa.yml.erb b/jobs/uaa/templates/uaa.yml.erb
index 67c529a..abc7e1d 100644
--- uaa.yml.erb
+++ uaa.yml.erb
@@ -183,7 +183,8 @@ zones:
   internal:
     hostnames:
       <% if_p('domain') do |domain| %>- <%= "login.#{domain}" %><% end %>
-      <% p_arr('uaa.zones.internal.hostnames').each do |hostname| %>- <%= hostname %><% end %>
+      <% p_arr('uaa.zones.internal.hostnames').each do |hostname| %>
+      - <%= hostname %><% end %>
 
 <% if_p('uaa.require_https') do |requireHttps| %>
 require_https: <%= requireHttps %>
EOF

touch "${SENTINEL}"
exit 0
