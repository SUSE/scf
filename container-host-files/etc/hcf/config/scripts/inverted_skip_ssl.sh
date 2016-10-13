#!/bin/bash

# We need the opposite of SKIP_CERT_VERIFY_INTERNAL for the loggregator
# and doppler, and we don't want the user to have to set it

if [[ "${SKIP_CERT_VERIFY_INTERNAL:-}" == "true" ]] ; then
  export DONT_SKIP_CERT_VERIFY_INTERNAL=false
else
  export DONT_SKIP_CERT_VERIFY_INTERNAL=true
fi
