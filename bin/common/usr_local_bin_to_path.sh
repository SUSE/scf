#!/usr/bin/env bash

# Add /usr/local/bin to non-login path, since tools are installed there
if ! grep ENV_SUPATH /etc/login.defs | grep -q /usr/local/bin; then
  sed -i '/ENV_SUPATH/s/$/:\/usr\/local\/bin/' /etc/login.defs
fi

if ! grep secure_path= /etc/sudoers | grep -q /usr/local/bin; then
  sed -i 's@secure_path="\(.*\)"@secure_path="\1:/usr/local/bin"@g' /etc/sudoers
fi
