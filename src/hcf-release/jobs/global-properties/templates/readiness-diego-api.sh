#!/bin/sh

# Readiness probe script for the diego-database role

exec /usr/bin/curl                                       \
    --data ''                                            \
    --fail                                               \
    --resolve 'diego-api:8889:127.0.0.1'                 \
    --cert '/var/vcap/jobs/bbs/config/certs/server.crt'  \
    --key '/var/vcap/jobs/bbs/config/certs/server.key'   \
    --cacert '/var/vcap/jobs/bbs/config/certs/ca.crt'    \
    'https://diego-api:8889/v1/ping'
