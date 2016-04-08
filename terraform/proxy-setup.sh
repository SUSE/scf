#!/bin/sh

set -o errexit -o nounset

if test $(id -u) -ne '0' ; then
  exec sudo "${0}"
fi

apt-get update
apt-get install -yq squid3
service squid3 stop || true
cp /tmp/proxy.conf /etc/squid3/squid.conf
service squid3 start
