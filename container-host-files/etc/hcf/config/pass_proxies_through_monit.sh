#!/usr/bin/env bash

# Because everything runs under monit, and monit _wipes the environment_, we
# will need to stash it somewhere and restore it via a script that gets
# executable before the real thing

if test "${#@}" != 0 ; then
    # This is being run from monit
    while read line ; do
        eval "export ${line}"
    done < /etc/environment
    exec "$@"
    exit 1 # Not reached
fi

# This is being run with no arguments, from run.sh.
# Save the environment.
set -o errexit -o nounset
chmod a+x "$(readlink -f "${BASH_SOURCE[0]}")"
for env in http_proxy https_proxy ftp_proxy no_proxy; do
    for k in "${env}" "${env^^}" ; do
        if test -z "${!k:-}" ; then
            continue
        fi
        echo "${k}=${!k}" >> /etc/environment
    done
done
for file in /var/vcap/monit/*monitrc ; do
    if ! test -e "${file}" ; then
        continue # In case no files were found
    fi
    perl -p -i -e 's!(^\s*start program ")(.*")$!\1'"$(readlink -f "${BASH_SOURCE[0]}")"' \2!' "${file}"
done
exit 0
