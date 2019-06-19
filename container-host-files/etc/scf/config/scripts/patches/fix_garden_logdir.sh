#!/bin/sh
# This patch re-adds the command to create the log directory for garden
set -e

PATCH_DIR=/var/vcap/jobs-src/garden/templates/bin
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- garden_ctl	2019-05-23 14:21:37.655428344 -0700
+++ garden_ctl	2019-05-23 14:22:04.235429437 -0700
@@ -5,6 +5,7 @@
 # shellcheck disable=SC1091
 source /var/vcap/jobs/garden/bin/envs
 
+mkdir -p "${LOG_DIR}"
 exec 1>> "${LOG_DIR}/garden_ctl.stdout.log"
 exec 2>> "${LOG_DIR}/garden_ctl.stderr.log"
PATCH

touch "${SENTINEL}"

exit 0

exit 0
