#!/usr/bin/env bash

# warden/root/linux/setup.sh mounts four proc-like filesystems under /tmp/warden/cgroup in setup
# It assumes that if /tmp/warden/cgroup exists the systems have already been mounted.
# When a container is stopped, docker automatically unmounts them, but it doesn't delete cgroup,
# so the startup script in setup.sh won't re-mount the systems.
# This code finishes the job. If other stuff ends up in this directory, all bets are off.

cgroup_path=/tmp/warden/cgroup
if [[ -d $cgroup_path && -z `ls -A $cgroup_path` ]] ; then
    rmdir $cgroup_path
fi
