#!/bin/bash
set -e

# Usage: setup_overlay_network.sh <OVERLAY_SUBNET> <OVERLAY_GATEWAY>
overlay_subnet=$1
overlay_gateway=$2

docker network create -d overlay --subnet="${overlay_subnet}" --gateway="${overlay_gateway}" hcf 
