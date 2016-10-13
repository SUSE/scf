#!/bin/bash
# This script sets the diego-cell / rep memory limits on this node, since `auto`
# can be incorrect when running inside a nested container (in which case the
# physical limits are much larger than the container limits)

# Note that this is sourced in the environment (before the BOSH templates are
# evaluated), and as such we should avoid setting unnecessary variables

if test "${DIEGO_CELL_MEMORY_CAPACITY_MB:-}" = "auto" ; then
    if test \
            $(cat /proc/meminfo | awk '/MemTotal:/ { printf "%.0f\n", $2 * 1024 }') \
        -gt \
            $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || bc <<< '2 ^ 63')
    then
        export DIEGO_CELL_MEMORY_CAPACITY_MB=$(
            awk '{ printf "%.0f\n", $1 / 1024 / 1024 }' /sys/fs/cgroup/memory/memory.limit_in_bytes
        )
    fi
fi
