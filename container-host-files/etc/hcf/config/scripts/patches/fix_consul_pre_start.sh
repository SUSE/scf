set -e

PATCH_DIR="/var/vcap/jobs-src/consul_agent/templates/"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' pre_start_patch <<'PATCH' || true
--- pre-start.erb.orig  2017-05-29 07:45:08.533020773 +0000
+++ pre-start.erb       2017-05-29 07:46:17.264617261 +0000
@@ -12,15 +12,28 @@
   local resolvconf_file
   resolvconf_file=/etc/resolvconf/resolv.conf.d/head

-  if ! grep -qE '127.0.0.1\\b' "${resolvconf_file}"; then
-          if [[ "$(stat -c "%s" "${resolvconf_file}")" = "0" ]]; then
-                  echo 'nameserver 127.0.0.1' > "${resolvconf_file}"
-          else
-                  sed -i -e '1i nameserver 127.0.0.1' "${resolvconf_file}"
-          fi
-  fi
+  local network_config_file
+  network_config_file=/etc/sysconfig/network/config
+
+  if [ -e "$resolvconf_file" ]; then
+    if ! grep -qE '127.0.0.1\\b' "${resolvconf_file}"; then
+      if [[ "$(stat -c "%s" "${resolvconf_file}")" = "0" ]]; then
+        echo 'nameserver 127.0.0.1' > "${resolvconf_file}"
+      else
+        sed -i -e '1i nameserver 127.0.0.1' "${resolvconf_file}"
+      fi
+    fi

-  resolvconf -u
+    resolvconf -u
+  elif [ -e "$network_config_file" ]; then
+    # openSUSE doesn't follow the resolv.conf.d convention but uses /etc/sysconfig/network for
+    # configuration instead
+    if ! grep -qE 'NETCONFIG_DNS_STATIC_SERVERS.*127.0.0.1' "${network_config_file}"; then
+      sed -i -e 's/NETCONFIG_DNS_STATIC_SERVERS="/NETCONFIG_DNS_STATIC_SERVERS="127.0.0.1 /' "${network_config_file}"
+    fi
+
+    service network restart
+  fi
 }

 function create_directories_and_chown_to_vcap() {
PATCH

cd "$PATCH_DIR"

echo -e "${pre_start_patch}" | patch --force

touch "${SENTINEL}"

exit 0


