#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/nfsv3driver/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p4 <<'PATCH'
diff --git a/jobs/nfsv3driver/templates/install.erb b/jobs/nfsv3driver/templates/install.erb
index 6f453da..0026b2e 100755
--- a/jobs/nfsv3driver/templates/install.erb
+++ b/jobs/nfsv3driver/templates/install.erb
@@ -2,6 +2,9 @@
 
 set -e -x
 
+# Figure out where the libraries should be installed.
+libdir="/usr/$(dirname "$(ldconfig -p | awk '/libc.so/ { print $NF }')")"
+
 # make sure there arent any existing fuse-nfs mounts
 pkill fuse-nfs | true
 for i in {1..60}; do
@@ -19,15 +22,15 @@ mkdir -p /var/vcap/packages/fuse-nfs/bin
 chown cvcap /var/vcap/packages/fuse-nfs/bin || true
 
 pushd /var/vcap/packages/fuse-nfs/fuse-2.9.2
-cp lib/.libs/*.so /usr/lib
+cp lib/.libs/*.so "${libdir}"
 cp util/fusermount /var/vcap/packages/fuse-nfs/bin
 chmod u+s /var/vcap/packages/fuse-nfs/bin/fusermount
 popd
 
 echo "Copying libnfs Shared Objects"
 pushd /var/vcap/packages/fuse-nfs/libnfs-1.11.0
-cp lib/.libs/*.so /usr/lib
-cp lib/.libs/*.so.8 /usr/lib
+cp lib/.libs/*.so "${libdir}"
+cp lib/.libs/*.so.8 "${libdir}"
 popd
 
 echo "Adding fuse-nfs to PATH"
PATCH

touch "${SENTINEL}"

exit 0
