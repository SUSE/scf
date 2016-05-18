#!/usr/bin/env bash

# Note: There should be a way to not hardwire "hcf", "3306", and "1936"

CFG=/usr/local/etc/haproxy/haproxy.cfg
if [[ -n "${MYSQL_PROXY_HOST}" ]] ; then
    echo "  server ${MYSQL_PROXY_HOST}  ${MYSQL_PROXY_HOST}.hcf:3306 check port 1936" >> $CFG
fi
if [[ -n "${MYSQL_PROXY_HA_HOST_1}" ]] ; then
    echo "  server ${MYSQL_PROXY_HA_HOST_1} ${MYSQL_PROXY_HA_HOST_1}.hcf:3306 backup check port 1936" >> $CFG
fi
if [[ -n "${MYSQL_PROXY_HA_HOST_2}" ]] ; then
    echo "  server ${MYSQL_PROXY_HA_HOST_2} ${MYSQL_PROXY_HA_HOST_2}.hcf:3306 backup check port 1936" >> $CFG
fi

# And now call the regular haproxy wrapper
exec /docker-entrypoint.sh haproxy -f $CFG "$@"
