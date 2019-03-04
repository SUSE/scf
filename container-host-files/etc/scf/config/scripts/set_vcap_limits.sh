#!/bin/bash

set -o errexit -o nounset

if [ -z "${DIEGO_VCAP_HARD_NPROC:-}" ] && [ -z "${DIEGO_VCAP_SOFT_NPROC:-}" ]; then
  exit 0
fi

LIMITS_FILEPATH="/etc/security/limits.conf"

print_err() {
  echo -e "\e[31m## ${1}" >&2
}

if [ -n "${DIEGO_VCAP_HARD_NPROC:-}" ] && [ -z "${DIEGO_VCAP_SOFT_NPROC:-}" ]; then
  print_err "DIEGO_VCAP_SOFT_NPROC must be set when DIEGO_VCAP_HARD_NPROC is set"
  exit 1
fi

if [ -n "${DIEGO_VCAP_SOFT_NPROC:-}" ] && [ -z "${DIEGO_VCAP_HARD_NPROC:-}" ]; then
  print_err "DIEGO_VCAP_HARD_NPROC must be set when DIEGO_VCAP_SOFT_NPROC is set"
  exit 1
fi

if (( "${DIEGO_VCAP_SOFT_NPROC}" > "${DIEGO_VCAP_HARD_NPROC}" )); then
  print_err "DIEGO_VCAP_SOFT_NPROC (${DIEGO_VCAP_SOFT_NPROC}) cannot be larger than DIEGO_VCAP_HARD_NPROC (${DIEGO_VCAP_HARD_NPROC})"
  exit 1
fi

echo "Setting hard nproc limit for vcap: ${DIEGO_VCAP_HARD_NPROC}"
sed -i "s|\(vcap[ ]*hard[ ]*nproc[ ]*\)[0-9]*|\1${DIEGO_VCAP_HARD_NPROC}|" "${LIMITS_FILEPATH}"

echo "Setting soft nproc limit for vcap: ${DIEGO_VCAP_SOFT_NPROC}"
sed -i "s|\(vcap[ ]*soft[ ]*nproc[ ]*\)[0-9]*|\1${DIEGO_VCAP_SOFT_NPROC}|" "${LIMITS_FILEPATH}"
