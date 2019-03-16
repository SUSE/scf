#!/bin/bash

set -o errexit -o nounset

if [ -z "${VCAP_HARD_NPROC:-}" ] && [ -z "${VCAP_SOFT_NPROC:-}" ]; then
  exit 0
fi

LIMITS_FILEPATH="/etc/security/limits.conf"

print_err() {
  echo -e "\e[31m## ${1}" >&2
}

if [ -n "${VCAP_HARD_NPROC:-}" ] && [ -z "${VCAP_SOFT_NPROC:-}" ]; then
  print_err "VCAP_SOFT_NPROC must be set when VCAP_HARD_NPROC is set"
  exit 1
fi

if [ -n "${VCAP_SOFT_NPROC:-}" ] && [ -z "${VCAP_HARD_NPROC:-}" ]; then
  print_err "VCAP_HARD_NPROC must be set when VCAP_SOFT_NPROC is set"
  exit 1
fi

if (( "${VCAP_SOFT_NPROC}" > "${VCAP_HARD_NPROC}" )); then
  print_err "VCAP_SOFT_NPROC (${VCAP_SOFT_NPROC}) cannot be larger than VCAP_HARD_NPROC (${VCAP_HARD_NPROC})"
  exit 1
fi

echo "Setting hard nproc limit for vcap: ${VCAP_HARD_NPROC}"
sed -i "s|\(vcap[ ]*hard[ ]*nproc[ ]*\)[0-9]*|\1${VCAP_HARD_NPROC}|" "${LIMITS_FILEPATH}"

echo "Setting soft nproc limit for vcap: ${VCAP_SOFT_NPROC}"
sed -i "s|\(vcap[ ]*soft[ ]*nproc[ ]*\)[0-9]*|\1${VCAP_SOFT_NPROC}|" "${LIMITS_FILEPATH}"
