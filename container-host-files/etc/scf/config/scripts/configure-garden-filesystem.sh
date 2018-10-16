#!/bin/sh
 if [ "$GARDEN_ROOTFS_DRIVER" == "overlay-xfs" ]; then
  export GARDEN_DISABLE_BTRFS="true"
fi

