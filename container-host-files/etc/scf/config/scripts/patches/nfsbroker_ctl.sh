#! /usr/bin/env bash

set -e

PATCH_DIR=/var/vcap/jobs-src/nfsbroker/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- ctl.erb
+++ ctl.erb
@@ -46,10 +46,10 @@ case $1 in
       --dbHostname="<%= p("nfsbroker.db_hostname") %>" \
       --dbPort="<%= p("nfsbroker.db_port") %>" \
       --dbName="<%= p("nfsbroker.db_name") %>" \
-      --dbCACertPath=/var/vcap/jobs/nfsbroker/db_ca.crt \
+<% if_p("nfsbroker.db_ca_cert") do |x| %> --dbCACertPath=/var/vcap/jobs/nfsbroker/db_ca.crt <% end %> \
       --credhubURL="<%= p("nfsbroker.credhub.url") %>" \
-      --credhubCACertPath=/var/vcap/jobs/nfsbroker/credhub_ca.crt \
-      --uaaCACertPath=/var/vcap/jobs/nfsbroker/uaa_ca.crt \
+<% if_p("nfsbroker.credhub.ca_cert") do |x| %> --credhubCACertPath=/var/vcap/jobs/nfsbroker/credhub_ca.crt <% end %> \
+<% if_p("nfsbroker.credhub.uaa_ca_cert") do |x| %> --uaaCACertPath=/var/vcap/jobs/nfsbroker/uaa_ca.crt <% end %> \
       --uaaClientID="<%= p("nfsbroker.credhub.uaa_client_id") %>" \
       --uaaClientSecret="<%= p("nfsbroker.credhub.uaa_client_secret") %>" \
       --storeID="<%= p("nfsbroker.store_id") %>" \
PATCH

touch "${SENTINEL}"

exit 0
