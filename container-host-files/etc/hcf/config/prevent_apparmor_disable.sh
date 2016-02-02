#!/usr/bin/env bash

# runner attempts to disable apparmor which ends up disabling it on the host
# preventing other containers from starting. It checks for this init script
# before doing so, so we move it to a different location.

if [[ -f /etc/init.d/apparmor ]] ; then
    mv /etc/init.d/apparmor /etc/init.d/apparmor_host
fi
