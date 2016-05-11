#!/bin/bash
set -e

export POSTGRES_PASSWORD=$DEVSVC_POSTGRES_ADMIN_PASSWORD 
exec /docker-entrypoint.sh "$@"