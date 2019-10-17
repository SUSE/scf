#!/usr/bin/env bash

set -o errexit -o nounset

target="/var/vcap/all-releases/jobs-src/uaa/uaa/templates/bin/uaa.erb"

# Patch bin/uaa.erb for the certificates to work with SUSE.
PATCH=$(cat <<'EOT'
49c49
< cp /etc/ssl/certs/ca-certificates.crt "$CERT_FILE"
---
> cp /var/lib/ca-certificates/ca-bundle.pem "$CERT_FILE"
EOT
)

# Only patch once
if ! patch --reverse --dry-run -f "${target}" <<<"$PATCH" 2>&1  >/dev/null ; then
  patch --verbose "${target}" <<<"$PATCH"
else
  echo "Patch already applied. Skipping"
fi