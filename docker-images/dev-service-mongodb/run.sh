#!/bin/bash
set -e

export MONGODB_PASS=$DEVSVC_MONGODB_ADMIN_PASSWORD
exec /bin/sh -c "$@"