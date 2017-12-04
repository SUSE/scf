#!/bin/sh

# Readiness probe script for the etcd role

exec /usr/bin/curl                                       \
    --fail                                               \
    --resolve 'etcd:4001:127.0.0.1'                      \
    --cert '/var/vcap/jobs/etcd/config/certs/client.crt' \
    --key '/var/vcap/jobs/etcd/config/certs/client.key'  \
    'https://etcd:4001/v2/stats/leader'
