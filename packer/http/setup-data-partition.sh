#!/usr/bin/env bash

# Set up the /data partition for AWS

set -o errexit -o xtrace -o nounset
exec >&2

debug() {
    "$@" || true
}

debug lsblk
debug partx --show - /dev/nvme0n1

for device in xvdb nvme1n1 nvme0n1 ; do
    if [ -e "/dev/${device}" ] ; then
        break
    fi
done
if [ ! -e "/dev/${device}" ] ; then
    echo "No device found for /data" >&2
    exit 0
fi

debug sfdisk --list "/dev/${device}"
if ! sfdisk --list "/dev/${device}" | grep "Linux filesystem" ; then
    # No partitions, create it
    printf 'label: gpt\n- - L\n' | sfdisk "/dev/${device}"
fi

debug sfdisk --list "/dev/${device}"
debug lsblk --fs

partition="$(lsblk --fs --pairs "/dev/${device}" | perl -e 'while(<>) { /NAME="(.*?)"/ && { $p = $1 } } ; print $p')"

if ! lsblk --fs "/dev/${partition}" | grep --silent ext4 ; then
    # No filesystem
    mkfs.ext4 "/dev/${partition}"
fi

mkdir -p /data

if ! systemctl cat data.mount | grep --silent "What=/dev/${partition}" ; then
    cat <<EOF | sed 's@ *@@' > /etc/systemd/system/data.mount
        [Unit]
        Description=Mount unit for the /data partition on aws-slave
        Before=local-fs.target

        [Install]
        RequiredBy=local-fs.target

        [Mount]
        Where=/data
        What=/dev/${partition}
EOF
    systemctl daemon-reload
fi

service=setup-data-partition.service
if ! systemctl list-units "${service}" | grep --silent "${service}" ; then
    cat <<EOF | sed 's@ *@@' > "/etc/systemd/system/${service}"
        [Unit]
        Description=Set up data partition on aws-slave
        Before=data.mount

        [Install]
        RequiredBy=data.mount

        [Service]
        Type=oneshot
        RemainAfterExit=true
        ExecStart=$0
EOF
fi
