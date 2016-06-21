set -e

PATCH_DIR="/var/vcap/jobs-src/uaa/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' uaa_yaml_patch <<'PATCH' || true
--- a/jobs/uaa/templates/uaa.yml.erb
+++ b/jobs/uaa/templates/uaa.yml.erb
@@ -191,7 +191,9 @@ zones:
   internal:
     hostnames:
       <% if_p('domain') do |domain| %>- <%= "login.#{domain}" %><% end %>
-      <% p_arr('uaa.zones.internal.hostnames').each do |hostname| %>- <%= hostname %><% end %>
+      <% p_arr('uaa.zones.internal.hostnames').each do |hostname| %>
+      - <%= hostname %>
+      <% end %>

 <% if_p('uaa.require_https') do |requireHttps| %>
 require_https: <%= requireHttps %>
PATCH

cd "$PATCH_DIR"

echo -e "${uaa_yaml_patch}" | patch --force

touch "${SENTINEL}"

exit 0
