#!/bin/sh

# This script checks if swapaccounting is enabled on the kernel.

if [ ! -e /sys/fs/cgroup/memory/memory.memsw.limit_in_bytes ]; then
	red='\033[0;31m'
	no_color='\033[0m'
	(>&2 printf "${red}")
	(>&2 printf "cgroup swap accounting is currently not enabled.")
	(>&2 printf " You should enable it on all your k8s nodes by setting the boot option \"swapaccount=1\".")
	(>&2 printf "${no_color}\\n")
	sleep 60
	exit 1
fi
