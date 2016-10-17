#!/bin/bash

set -o errexit
set -o xtrace

function random_suffix { head -c2 /dev/urandom | hexdump -e '"%04x"'; }
CF_ORG=${CF_ORG:-org}-$(random_suffix)
CF_SPACE=${CF_SPACE:-space}-$(random_suffix)

# where do i live ?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# configuration
SGJ=${DIR}/../test-resources/secgroup.json

# create security group
cf create-security-group internal-services-workaround ${SGJ}

# Bind security groups for containers that run apps
cf bind-running-security-group internal-services-workaround

# Bind security groups for containers that stage apps
cf bind-staging-security-group internal-services-workaround

# unbind security groups for containers that stage apps
cf unbind-staging-security-group internal-services-workaround

# unbind security groups for containers that run apps
cf unbind-running-security-group internal-services-workaround

# create security group
cf delete-security-group -f internal-services-workaround
