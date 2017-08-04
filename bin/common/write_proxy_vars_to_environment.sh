#!/usr/bin/env bash
set -o errexit
for var in no_proxy http_proxy https_proxy NO_PROXY HTTP_PROXY HTTPS_PROXY ; do
  if test -n "${!var}" ; then
    echo "${var}=${!var}" | tee -a /etc/environment
  fi
done
echo Proxy setup of the host, saved ...
