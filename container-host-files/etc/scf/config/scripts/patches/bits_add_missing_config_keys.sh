#! /usr/bin/env bash

# This is a temporary patch needed to configure the BITS service
# in a manner compatible with Eirini

set -e

PATCH_DIR=/var/vcap/jobs-src/bits-service/templates
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

cat <<EOT >> /var/vcap/jobs-src/bits-service/templates/bits_config.yml.erb

registry_endpoint: https://registry.${DOMAIN}
enable_registry: true
rootfs:
  blobstore_type: local
  local_config:
    path_prefix: /var/vcap/store/bits-service/

EOT

touch "${SENTINEL}"

exit 0
