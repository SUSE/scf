#!/bin/bash

set -o errexit
set -o xtrace

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
