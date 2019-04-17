#!/usr/bin/env bash

# Provision the custom config scripts and personal setup.

set -o errexit -o nounset

MOUNTED_CUSTOM_SETUP_SCRIPTS=$1

if [ -d "${MOUNTED_CUSTOM_SETUP_SCRIPTS}/provision.d" ]; then
  echo -e "\e[1;96mRunning customization scripts\e[0m"
  scripts=($(find "${MOUNTED_CUSTOM_SETUP_SCRIPTS}/provision.d" -iname "*.sh" -executable -print | sort))
  for script in "${scripts[@]}"; do
    echo -e "Running \e[1;96m${script}\e[0m"
    "${script}"
  done
  echo -e "\e[1;96mDone running customization scripts\e[0m"
fi

echo 'test -f "${HOME}/scf/personal-setup" && . "${HOME}/scf/personal-setup"' >> .profile
