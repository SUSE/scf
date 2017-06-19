#!/bin/bash

# This script pulls the UAA verification key from the live UAA instance, instead
# of the value passed in from the environment.
# It is only applicable to HCP deployments (where we have an external UAA); on
# Vagrant deployments this is unused.

# Note that this is *sourced* into run.sh, so we can't exit the shell.


# Report progress to the user; use as printf
status() {
    local fmt="${1}"
    shift
    printf "\n%b${fmt}%b\n" "\033[0;32m" "$@" "\033[0m"
}

# Report problem to the user; use as printf
trouble() {
    local fmt="${1}"
    shift
    printf "\n%b${fmt}%b\n" "\033[0;31m" "$@" "\033[0m"
}

# helper function to retry a command until it suceeds, with a delay between trials
# usage: retry_forever <delay> <command>...
function retry_forever () {
    delay=${1}
    shift 1

    while true ; do
        printf "Trying: %s\n" "$*"
        if "$@" ; then
            status ' SUCCESS'
            break
        fi
        trouble '  FAILED'
        status "Waiting ${delay} ..."
        sleep "${delay}"
    done
}

SKIP=$(if test "${SKIP_CERT_VERIFY_EXTERNAL}" = "true" ; then echo "--insecure" ; fi)

status "Waiting for UAA to be available at ${HCF_UAA_INTERNAL_URL}/token_key ..."
retry_forever 10s curl --connect-timeout 5 --fail $SKIP "${HCF_UAA_INTERNAL_URL}/token_key"

status "Extract JWT public signing key"
export JWT_SIGNING_PUB="$(\
    { curl --fail $(if test "${SKIP_CERT_VERIFY_EXTERNAL}" = "true" ; then echo "--insecure" ; fi)\
        "${HCF_UAA_INTERNAL_URL}/token_key" \
        || exit 1 \
    ; } \
    | awk 'BEGIN { RS="," ; FS="\"" } /value/ { if ($2 == "value") print $4 } ')"

status DONE
