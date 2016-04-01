#!/bin/bash
set -e

export MYSQL_ROOT_PASSWORD=$DEVSVC_MYSQL_ADMIN_PASSWORD
exec /bin/sh -c "$@"