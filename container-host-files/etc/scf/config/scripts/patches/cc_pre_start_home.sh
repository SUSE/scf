#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/cloud_controller_ng/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- migrate_db.sh.erb	2018-11-14 18:29:27.530328727 +0000
+++ migrate_db.sh.erb	2018-11-14 18:29:58.470328727 +0000
@@ -34,6 +34,7 @@
 }

 function main {
+  export HOME=/home/vcap # rake needs it to be set to run tasks
   migrate
 }

PATCH

touch "${SENTINEL}"

exit 0
