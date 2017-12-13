#!/bin/sh

set -o errexit
set -o verbose

# Fetch predetermined version of scf
SCF_URL=https://github.com/SUSE/scf/releases/download/2.4.1-beta3/scf-opensuse-2.4.1-beta3.cf278.0.g12f5d3a8.linux-amd64.zip
SCF_ARCHIVE="$(basename "${SCF_URL}")"
wget "${SCF_URL}"
unzip "${SCF_ARCHIVE}"

# Fetch predetermined version of the ui
CONSOLE_URL=https://github.com/SUSE/stratos-ui/releases/download/0.9.9/console-helm-chart-0.9.9.tgz
CONSOLE_ARCHIVE="$(basename "${CONSOLE_URL}")"
wget "${CONSOLE_URL}"
tar xzf "${CONSOLE_ARCHIVE}"
