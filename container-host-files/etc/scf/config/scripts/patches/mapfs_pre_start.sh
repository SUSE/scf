#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/mapfs/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

# This adds support for SUSE-like systems to install fuse:
# - Detect installed fuse support and skip installation of pre-packaged (ubuntu) debs
# - Don't use `adduser`, use `useradd`.
# - SUSE support is installed in a custom job's pre-start script, from a pre-packaged rpm.
# - Reworks ubuntu code somewhat (modprobe specific to them, better version detection).

patch -d "$PATCH_DIR" <<'PATCH'
--- install.erb	2019-03-26 12:30:40.614236874 -0700
+++ install.erb	2019-03-26 14:39:32.565499697 -0700
@@ -4,22 +4,37 @@
 
 echo "Installing fuse"
 
-codename=$(lsb_release -c | awk '{print $2}')
-if [ "$codename" == "trusty" ]; then
-  (
-  flock -x 200
-  dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.2-4ubuntu4.14.04.1_amd64.deb
-  ) 200>/var/vcap/data/dpkg.lock
-elif [ "$codename" == "xenial" ]; then
-  (
-  flock -x 200
-  dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.4-1ubuntu3.1_amd64.deb
-  ) 200>/var/vcap/data/dpkg.lock
+lsb_id() {
+    awk -F= "/^${1}=/ { print \$2}" /etc/os-release | tr -d '"\n'
+}
+
+# Install fuse userspace support only if not present.
+if test -e /sbin/mount.fuse
+then
+    echo "Skipping installation, fuse already present"
+else
+    case "$(lsb_id ID)-$(lsb_id VERSION_ID)" in
+	ubuntu-14.04)
+            (
+		flock -x 200
+		dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.2-4ubuntu4.14.04.1_amd64.deb
+            ) 200>/var/vcap/data/dpkg.lock
+            modprobe fuse
+            ;;
+	ubuntu-16.04)
+            (
+		flock -x 200
+		dpkg  --force-confdef -i /var/vcap/packages/mapfs-fuse/fuse_2.9.4-1ubuntu3.1_amd64.deb
+            ) 200>/var/vcap/data/dpkg.lock
+            modprobe fuse
+            ;;
+    esac
 fi
 
-modprobe fuse
+echo "Configuring fuse"
+
 groupadd fuse || true
-adduser vcap fuse
+useradd fuse -g vcap
 chown root:fuse /dev/fuse
 cat << EOF > /etc/fuse.conf
 user_allow_other
PATCH

touch "${SENTINEL}"

exit 0
