#!/bin/bash
set -e

# Create a DNS server in docker hcf network that is exposed on the host
# to allow external hosts to use the internal DNS server from docker.
# I.e. a Windows box could resolve the 'diego-database.hcf' hostname if
# the DNS client is pointing to 192.168.77.77
docker run  -p 192.168.77.77:53:8600/udp --net=hcf -d --restart=always \
  --name dnsb voxxit/consul agent -data-dir /data -server -bootstrap \
  -client=0.0.0.0 -recursor=127.0.0.11
