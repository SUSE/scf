set -e

PATCH_DIR="/var/vcap/jobs-src/cf-mysql-broker/templates"
PATCH_SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ ! -f "${PATCH_SENTINEL}" ]; then
    read -r -d '' setup_patch_broker <<'PATCH' || true
--- cf-mysql-broker_ctl.erb
+++ cf-mysql-broker_ctl.erb
@@ -53,11 +53,11 @@ case $1 in

         # Create DB and run migrations
         set +e
-        su - vcap -p -c -o pipefail "PATH=$PATH bundle exec rake db:create 2>&1 \
+        su -m vcap -p -c -o pipefail "bundle exec rake db:create 2>&1 \
             | tee -a $LOG_DIR/db_migrate.combined.log \
             | logger -p local1.error -t mysql-broker-dbcreate"

-        su - vcap -p -c -o pipefail "PATH=$PATH bundle exec rake db:migrate 2>&1 \
+        su -m vcap -p -c -o pipefail "bundle exec rake db:migrate 2>&1 \
             | tee -a $LOG_DIR/db_migrate.combined.log \
             | logger -p local1.error -t mysql-broker-dbmigrate"

@@ -73,7 +73,7 @@ case $1 in

         # Sync size of existing service instances to match plans in manifest
         set +e
-        su - vcap -p -c -o pipefail "PATH=$PATH bundle exec rake broker:sync_plans_in_db 2>&1 \
+        su -m vcap -p -c -o pipefail "bundle exec rake broker:sync_plans_in_db 2>&1 \
             | tee -a $LOG_DIR/cf-mysql-broker.log \
             | logger -p local1.error -t mysql-broker-plans"

@@ -89,7 +89,7 @@ case $1 in
       popd
     fi

-    su - vcap -p -c -o pipefail "PATH=$PATH bundle exec unicorn -c $JOB_DIR/config/unicorn.conf.rb 2>&1 \
+    su -m vcap -p -c -o pipefail "bundle exec unicorn -c $JOB_DIR/config/unicorn.conf.rb 2>&1 \
         | tee -a $LOG_DIR/cf-mysql-broker.log \
         | logger -p local1.error -t mysql-broker &"
     ;;
PATCH

    cd "$PATCH_DIR"

    echo -e "${setup_patch_broker}" | patch --force

    touch "${PATCH_SENTINEL}"
fi

exit 0
