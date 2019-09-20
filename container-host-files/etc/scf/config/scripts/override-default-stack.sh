#!/bin/sh

set +x
if [ "${FEATURE_EIRINI_ENABLED}" == "true" ]; then
    export DEFAULT_STACK=cflinuxfs3
fi
