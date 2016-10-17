set -e

PATCH_DIR="/var/vcap/jobs-src/uaa/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_fix_uaa_interpolate <<'PATCH' || true
--- uaa.yml.erb.orig
+++ uaa.yml.erb
@@ -270,7 +270,7 @@
   #internal hostnames for subdomain mapping
   internal_hostnames = []
   if_p('domain') do |domain|
-    internal_hostnames.push('login.#{domain}')
+    internal_hostnames.push("login.#{domain}")
   end
   p_arr('uaa.zones.internal.hostnames').each do |hostname|
     internal_hostnames.push(hostname)
PATCH

cd "$PATCH_DIR"

echo -e "${setup_fix_uaa_interpolate}" | patch --force

touch "${SENTINEL}"

exit 0
