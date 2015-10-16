#!/usr/bin/env bash
set -e

if [[ $# < 1 || -z "$1" ]]; then
	echo "Usage: $0 <consul-address>"
	exit 1
fi

CONSUL_ADDRESS="$1"

until [[ $(curl -s "$CONSUL_ADDRESS/v1/status/leader") =~ [:digit]+ ]]; do
	echo "Waiting for consul to come online"
	sleep 1
done
echo "Consul up!"
