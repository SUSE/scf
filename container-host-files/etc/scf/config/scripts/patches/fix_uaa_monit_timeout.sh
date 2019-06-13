set -e
# Change the monit timeout for uaa, to allow for (very) slow database migration.

echo Patching uaa monit for longer timeout, allowing for very slow database migrations

# While the final monit spec will be found in /var/vcap/monit/ at the
# time this script runs the directory will not be filled yet.  That is
# done by configgin, comes after us.  Thus, we patch the input file to
# configgin instead.

sed -e 's/with timeout 60 seconds/with timeout 600 seconds/'  \
    -i /var/vcap/jobs-src/uaa/monit

echo OK

exit 0
