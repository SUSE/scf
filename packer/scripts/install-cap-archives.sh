#!/bin/sh

set -o errexit
set -o verbose

# Fetch predetermined version of scf
SCF_URL=https://github.com/SUSE/scf/releases/download/2.7.0/scf-opensuse-2.7.0.cf1.9.0.0.g2d95fcb5.linux-amd64.zip
SCF_ARCHIVE="$(basename "${SCF_URL}")"
wget "${SCF_URL}"
unzip "${SCF_ARCHIVE}"

# Fetch predetermined version of the ui
CONSOLE_URL=https://github.com/cloudfoundry-incubator/stratos/releases/download/1.0.0/console-helm-chart-1.0.0.tgz
CONSOLE_ARCHIVE="$(basename "${CONSOLE_URL}")"
wget "${CONSOLE_URL}"
tar xzf "${CONSOLE_ARCHIVE}"
