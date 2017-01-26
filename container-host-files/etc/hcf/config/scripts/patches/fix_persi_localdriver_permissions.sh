set -e

PATCH_DIR="/var/vcap/jobs-src/localdriver/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_localdriver_prestart <<'PATCH' || true
--- install.erb
+++ install.erb
@@ -10,5 +10,9 @@ MOUNT_DIR=<%= p("localdriver.cell_mount_path") %>
 mkdir -p $MOUNT_DIR
 chown vcap:vcap $MOUNT_DIR

+if [ -d "$MOUNT_DIR/_volumes" ]; then
+  chown vcap:vcap $MOUNT_DIR/_volumes
+fi
+
 echo "Installed localdriver paths"
 exit 0
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_localdriver_prestart}" | patch --force

touch "${SENTINEL}"

exit 0
