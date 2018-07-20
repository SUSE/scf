#!/bin/sh

set -o errexit
set -o verbose

if [ -f /tmp/scf-helmchart.zip ]; then
    unzip /tmp/scf-helmchart.zip
fi
if [ ! -f helm/cf-opensuse/Chart.yaml ]; then
    # Fetch predetermined version of scf
    SCF_URL=https://github.com/SUSE/scf/releases/download/2.8.0/scf-opensuse-2.8.0.cf1.15.0.0.g5aa8b036-amd64.zip
    SCF_ARCHIVE="$(basename "${SCF_URL}")"
    wget "${SCF_URL}"
    unzip "${SCF_ARCHIVE}"
fi

if [ -f /tmp/console-helmchart.zip ]; then
    unzip /tmp/console-helmchart.zip
fi
if [ ! -f console/Chart.yaml ]; then
    # Fetch predetermined version of the ui
    CONSOLE_URL=https://github.com/cloudfoundry-incubator/stratos/releases/download/1.1.0/console-helm-chart-1.1.0.tgz
    CONSOLE_ARCHIVE="$(basename "${CONSOLE_URL}")"
    wget "${CONSOLE_URL}"
    tar xzf "${CONSOLE_ARCHIVE}"
fi
