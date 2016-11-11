set -e

# This patch fixes a consul server so it has one name per IP address
# The thread for this bug https://github.com/hashicorp/consul/issues/457
# suggests this is the case.
# Consul won't come up correctly if a server with name X comes online using
# a different address.

PATCH_DIR="/var/vcap/jobs-src/consul_agent/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' patch_consul_server_name <<'PATCH' || true
--- a/jobs/consul_agent/templates/confab.json.erb
+++ b/jobs/consul_agent/templates/confab.json.erb
@@ -20,7 +20,7 @@

   {
     node: {
-      name: name,
+      name: discover_external_ip,
       index: spec.index,
       external_ip: discover_external_ip,
     },
PATCH

cd "$PATCH_DIR"

echo -e "${patch_consul_server_name}" | patch --force

touch "${SENTINEL}"

# We always assume index 0 has a good database when it starts up. We need to do
# this because if we only have one consul, we're essentially reconvering from an
# error state (based on consul documentation). In the case of an HA deployment,
# we have no guarantee that HCP will _not_ restart all consuls at once, losing
# quorum. So again we assume we are always in a recovering state. This might
# mean we may get some data loss in the event of failure of node 0 (to be
# tested).
if [ "${HCP_COMPONENT_INDEX}" == "0" ]; then
  if [ -d "/var/vcap/store/consul_agent/raft" ]; then
    touch /var/vcap/store/consul_agent/raft/peers.info
    echo "[\"$IP_ADDRESS:8300\"]" > /var/vcap/store/consul_agent/raft/peers.json
  fi
fi

exit 0
