#!/bin/bash

set -o errexit -o nounset

PATCH_DIR="/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/lib/tasks"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cd "${PATCH_DIR}"

patch -p3 --force <<EOF
diff --git a/lib/tasks/db.rake b/lib/tasks/db.rake
index b5a658ae8..f5481d585 100644
--- a/lib/tasks/db.rake
+++ b/lib/tasks/db.rake
@@ -44,7 +44,7 @@ end
   def migrate
     Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
     db_logger = Steno.logger("cc.db.migrations")
-    DBMigrator.from_config(RakeConfig.config, db_logger).apply_migrations
+    DBMigrator.from_config(RakeConfig.config, db_logger).apply_migrations(use_transactions: true)
   end
 
   desc "Perform Sequel migration to database"
EOF

touch "${SENTINEL}"
