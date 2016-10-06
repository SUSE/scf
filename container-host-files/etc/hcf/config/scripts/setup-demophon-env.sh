#!/bin/bash

set -o errexit -o nounset

# This scripts writes all environment variables to a script so they can
# be sourced later. Demophon needs the entrypoint's variables to do useful
# work, and monit whipes that data out.

mkdir -p /var/vcap/jobs/demophon/config/
touch /var/vcap/jobs/demophon/config/monit.env.sh

IFS=$'\n' # make newlines the only separator
for var in `compgen -A variable`
do
  (unset $var 2> /dev/null) && echo "export $var='`printenv $var`'" >> /var/vcap/jobs/demophon/config/monit.env.sh
done
