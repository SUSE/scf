#!/bin/sh

# This is a temporary workaround for UCP not giving us useful indexes between
# instances in the bosh spec.index style.  We generate a number based on the
# (randomized) host name and patch that into our configuration templates.

if test -z "${UCP_INSTANCE_ID}" ; then
    # This is not running on UCP; this is not needed
    exit 0
fi

set -o errexit -o nounset

index=$(hostname --short | sed 's@.*-@@' | od --address-radix=n --format=dL)

perl -p -i -e "s@^index:.*@index: ${index}@" /opt/hcf/env2conf.yml
