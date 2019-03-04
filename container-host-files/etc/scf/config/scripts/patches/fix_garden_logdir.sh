#!/bin/sh
# This patch re-adds the command to create the log directory for garden
set -e

PATCH_DIR=/var/vcap/jobs-src/garden/templates/bin
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- garden_start.erb	2019-03-04 13:49:04.802582929 -0800
+++ garden_start.erb	2019-03-04 13:49:23.218622592 -0800
@@ -6,6 +6,7 @@
 source /var/vcap/packages/greenskeeper/bin/system-preparation
 
 <% if !p("bpm.enabled") %>
+  mkdir -p "${LOG_DIR}"
   exec 1>> "${LOG_DIR}/garden_start.stdout.log"
   exec 2>> "${LOG_DIR}/garden_start.stderr.log"
 
PATCH

touch "${SENTINEL}"

exit 0

exit 0
