#!/bin/bash

set -eu

for mnt in "$@"; do
  if [[ ! "$mnt" =~ ^/exports/ ]]; then
    >&2 echo "Path to NFS export must be inside of the \"/exports/\" directory"
    exit 1
  fi
  mkdir -p $mnt
  chmod 777 $mnt
  echo "$mnt *(rw,sync,no_subtree_check,no_root_squash,fsid=0)" >> /etc/exports
done

exportfs -a
rpcbind
rpc.statd -p 662 -o 2020
rpc.nfsd

exec rpc.mountd -p 892 --foreground
