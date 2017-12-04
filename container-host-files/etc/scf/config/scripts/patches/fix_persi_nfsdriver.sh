set -e

# SUSE compatibility:
# - makes sure useradd adds a group for the cvcap user; 
#   by default this doesn't occur by default on SUSE; see `man useradd`` for details
# - adduser is not avalable on SUSE - use usermod instead

PATCH_DIR="/var/vcap/jobs-src/nfsv3driver/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' ctl_patch <<'PATCH' || true
--- ctl.erb.orig
+++ ctl.erb
@@ -18,7 +18,7 @@ case $1 in

   start)
     # make a new container cvcap user if it doesn't already exist
-    id -u cvcap &>/dev/null || useradd -u 2000 cvcap
+    id -u cvcap &>/dev/null || useradd --user-group -u 2000 cvcap

     mkdir -p $RUN_DIR
     chown -R cvcap:cvcap $RUN_DIR
PATCH

read -r -d '' install_patch <<'PATCH' || true
--- install.erb.orig
+++ install.erb
@@ -37,10 +37,10 @@ setcap 'cap_net_bind_service=+ep' /var/vcap/packages/fuse-nfs/bin/fuse-nfs
 popd

 # make a new container cvcap user if it doesn't already exist
-id -u cvcap &>/dev/null || useradd -u 2000 cvcap
+id -u cvcap &>/dev/null || useradd --user-group -u 2000 cvcap

 groupadd fuse | true
-adduser cvcap fuse
+usermod -aG fuse cvcap
 chown root:fuse /dev/fuse

 cat << EOF > /etc/fuse.conf
PATCH

cd "$PATCH_DIR"

echo -e "${ctl_patch}" | patch --force
echo -e "${install_patch}" | patch --force

touch "${SENTINEL}"

exit 0


