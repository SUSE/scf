#!/usr/bin/env bash
set -e

if [[ $# < 1 || -z "$1" ]]; then
	echo "Usage: $0 <consul-address>"
	exit 1
fi

CONSUL_ADDRESS="$1"

# Response from server will be either:
#  * nothing (server not up)
#  * "" (leader not elected)
#  * "{ip}:{port}" (leader elected, ready)
until [[ $(curl -s "$CONSUL_ADDRESS/v1/status/leader") =~ ^\"[0-9.:]+\" ]]; do
	echo "Waiting for consul to come online"
	sleep 1
done
echo "Consul up!"

