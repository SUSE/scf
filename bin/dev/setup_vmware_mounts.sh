#!/bin/bash

# Only run if we're on Workstation or Fusion
if hash vmhgfs-fuse 2>/dev/null; then
    releases=$FISSILE_RELEASE

    for release in $(echo $releases | sed "s/,/ /g")
    do
        if [ $(mount | grep -c $release/blobs) != 1 ] ; then
            echo "Mounting a dir for $release blobs ..."
            release_name=`basename ${release}`
            mkdir -p ~/bloblinks/${release_name}
            mkdir -p ${release}/blobs
            sudo mount --bind ~/bloblinks/${release_name} ${release}/blobs
        fi
    done
fi
