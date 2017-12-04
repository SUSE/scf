#!/bin/bash

# Usage: CATS_SUITES='+suite,suite,-suite,suite,=suite,suite,suite' $0
# e.g /usr/bin/env CATS_SUITES='-internet_dependent,+v3' $0
# A '+' means turn on the following suites; '-' means turn it off.
# '=' means disable all suites and turn on only the following ones.

ALL_SUITES='
    apps
    sso
    backend_compatibility
    detect
    diego_docker
    internet_dependent
    route_services
    routing
    security_groups
    services
    diego_ssh
    v3
'

declare -A suites
mode='invalid'
CATS_SUITES="${CATS_SUITES}," # Ensure we can always remove something
while test -n "${CATS_SUITES}" ; do
    case "${CATS_SUITES:0:1}" in
        ,)
            CATS_SUITES="${CATS_SUITES:1}" ;;
        +)
            mode=add
            CATS_SUITES="${CATS_SUITES:1}" ;;
        -)
            mode=remove
            CATS_SUITES="${CATS_SUITES:1}" ;;
        =)
            for suite in ${ALL_SUITES} ; do
                suites["${suite}"]=false
            done
            mode=add
            CATS_SUITES="${CATS_SUITES:1}" ;;
        *)
            suite="${CATS_SUITES%%,*}"
            if test -n "${suite}" ; then
                if ! echo "${ALL_SUITES}" | grep --word --quiet "${suite}" ; then
                    printf "Error: Unknown CATS suite %s\n" "${suite}" >&2
                    exit 1
                fi
                case "${mode}" in
                    add)    suites["${suite}"]=true;;
                    remove) suites["${suite}"]=false;;
                    *)      printf "Invalid CATS_SUITES syntax near %s\n" "${CATS_SUITES}" >&2
                            exit 1;;
                esac
            fi
            CATS_SUITES="${CATS_SUITES#*,}" ;;
    esac
done

for suite in ${ALL_SUITES} ; do
    if test -n "${suites[${suite}]}" ; then
        echo "properties.acceptance_tests.include_${suite}: ${suites[${suite}]}" >> /opt/fissile/env2conf.yml
    fi
done
