#!/usr/bin/env bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

set -e

if [[ $# < 2 || -z "$1" || -z "$2" ]]; then
  echo "Usage: consullin.bash <consul-address> <fissile-config-pack>"
  exit 1
fi

TMP_CONFIG_DIR=/tmp/hcf-config-import
CONSUL_ADDRESS="$1"
FISSILE_CFG_PACK="$2"

if [[ "$CONSUL_ADDRESS" != */ ]]; then
  CONSUL_ADDRESS="$CONSUL_ADDRESS/"
fi

if [ "$DEBUG" != "" ] ; then
  set -x
fi

mkdir -p $TMP_CONFIG_DIR
tar xzf "$FISSILE_CFG_PACK" -C "$TMP_CONFIG_DIR"

cd $TMP_CONFIG_DIR
echo "Creating kv values"
for file in $(find . | grep "/value.yml$"); do
  output=$(curl -s -X PUT -d "$(cat $file)" "$CONSUL_ADDRESS""v1/kv""$(dirname $file | sed 's@\.@@' )")
  if [[ $output != "true" ]]; then
    echo "Creating kv pair failed"
    echo "Key: $(dirname $file)"
    echo "Value: $(cat $file)"
    echo "Output: $output"
    exit 1
  fi
done

rm -r $TMP_CONFIG_DIR
