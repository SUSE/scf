#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/postgres/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- pre-start.sh.erb	2019-04-02 12:36:41.627306990 -0700
+++ pre-start.sh.erb	2019-04-02 13:51:25.937193032 -0700
@@ -53,7 +53,8 @@
   chmod -R 600 ${PG_CERTS_DIR}/*
   chown -R vcap:vcap ${PG_CERTS_DIR}/*
 
-  sysctl -w "kernel.shmmax=284934144"
+  # Disabled, fails in container
+  #sysctl -w "kernel.shmmax=284934144"
 }
 
 main
PATCH

touch "${SENTINEL}"

exit 0
