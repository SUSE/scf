#!/bin/sh

# This script checks if swap is available, and if yes, if swapaccounting is
# enabled on the kernel.  It is an error to have swap without swapaccounting (as
# that would lead to mis-tracking of memory usage).  If there is no swap,
# however, not having swap accounting is safe; in that case we turn it off for
# garden as well.

# If there is no swap, we can drop the swap accounting requirement.
no_swap="$(awk '/^SwapTotal:/ { print ($2 == 0) ? "true" : "false" }' /proc/meminfo)"

if [ ! "${no_swap}" ] && [ ! -e /sys/fs/cgroup/memory/memory.memsw.limit_in_bytes ]; then
	red='\033[0;31m'
	no_color='\033[0m'
	(>&2 printf "${red}")
	(>&2 printf "cgroup swap accounting is currently not enabled.")
	(>&2 printf " You should enable it on all your k8s nodes by setting the boot option \"swapaccount=1\".")
	(>&2 printf "${no_color}\\n")
	sleep 60
	exit 1
fi

echo "properties.garden.disable_swap_limit: ${no_swap}" >> /opt/fissile/env2conf.yml
