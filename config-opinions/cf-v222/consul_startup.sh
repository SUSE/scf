set -e

# Available environment variables:
# CONSUL_ADDRESS
# CONFIG_STORE_PREFIX
# ROLE_INSTANCE_INDEX
# IP_ADDRESS
# DNS_RECORD_NAME

success=$(curl -X PUT -d "[\"$IP_ADDRESS\"]" $CONSUL_ADDRESS/v1/kv/$CONFIG_STORE_PREFIX/user/consul/agent/servers/lan)
rc=0
[[ "$success" == "true" ]] || rc=$?
exit $rc
