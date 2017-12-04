#!/usr/bin/env bash

# This script is meant to be run on a MySQL when it's IST is failing due
# to a bad address. It optionally takes a gcache size in case the customer
# has modified it.

set -o errexit
set -o pipefail

if [ "${#}" -eq 0 ]
then
  echo "Usage: ${0} <scf_instance_id> [gcache_size]"
  exit 1
fi

INSTANCE_ID="${1}"
GCACHE_SIZE="${2:-512}"
IP_ADDRESS=$(ip -4 -o a show dev eth0 | awk '{print $4}' | sed 's@/[0-9]\+@@')

read -r -d '' setup_patch_my_cnf <<PATCH || true
--- /var/vcap/jobs/mysql/config/my.cnf 2017-01-20 21:24:05.548818434 +0000
+++ /var/vcap/jobs/mysql/config/my.cnf 2017-01-20 23:51:48.293842679 +0000
@@ -11,7 +11,8 @@
 # GALERA options:
 wsrep_on=ON
 wsrep_provider=/var/vcap/packages/mariadb/lib/plugin/libgalera_smm.so
-wsrep_provider_options="gcache.size=${GCACHE_SIZE}M;pc.recovery=TRUE;pc.checksum=TRUE"
+wsrep_provider_options="gcache.size=${GCACHE_SIZE}M;pc.recovery=TRUE;pc.checksum=TRUE;ist.recv_addr=${IP_ADDRESS}:4568"
+wsrep_sst_receive_address='${IP_ADDRESS}:4444'
 wsrep_cluster_address="gcomm://mysql-0.${INSTANCE_ID}.svc,mysql-1.${INSTANCE_ID}.svc,mysql-2.${INSTANCE_ID}.svc"
 wsrep_node_address='mysql-1.${INSTANCE_ID}.svc:4567'
 wsrep_node_name='mysql/1'
PATCH

echo -e "${setup_patch_my_cnf}" | patch -p0
