#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/nfsbroker/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- credhub_ca.crt.erb
+++ credhub_ca.crt.erb
@@ -1 +1 @@
-<%= p("nfsbroker.credhub.ca_cert") %>
+<% if_p("nfsbroker.credhub.ca_cert") do |ca_cert| %><%= ca_cert %><% end %>
--- db_ca.crt.erb
+++ db_ca.crt.erb
@@ -1 +1 @@
-<%= p("nfsbroker.db.ca_cert") %>
+<% if_p("nfsbroker.db_ca_cert") do |ca_cert| %><%= ca_cert %><% end %>
PATCH

touch "${SENTINEL}"

exit 0
