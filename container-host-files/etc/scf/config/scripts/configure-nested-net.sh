#!/bin/bash
 if test -z "${SCF_INSTANCE_ID}" ; then
    # This is not running on CAASP; this is not needed
    exit 0
fi
 if test -z "${KUBE_COMPONENT_INDEX}" ; then
    printf "Your CAASP is broken; no index was specified\n" >&2
    exit 1
fi
 if test "${DIEGO_CELL_SUBNET}" == "${DIEGO_CELL_SUBNET%.0.0/16}" ; then
    printf "Your diego cell subnet pool must be a /16\n" >&2
    exit 1
fi
 target_prefix="${DIEGO_CELL_SUBNET%.0.0/16}"
 if test "${KUBE_COMPONENT_INDEX}" -lt 0 -o "${KUBE_COMPONENT_INDEX}" -gt 254 ; then
    printf "Instance index %s is not supported\n" "${KUBE_COMPONENT_INDEX}" >&2
    exit 1
fi
 cell_subnet="${target_prefix}.${KUBE_COMPONENT_INDEX}.0/24"
 perl -p -i -e "s@^properties.garden.network_pool:.*@properties.garden.network_pool: ${cell_subnet}@" /opt/fissile/env2conf.yml
