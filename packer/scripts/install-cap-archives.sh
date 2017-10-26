#!/bin/sh

set -o errexit
set -o verbose

# Fetch predetermined version of scf
SCF_URL=https://github.com/SUSE/scf/releases/download/2.2.0-beta/scf-2.2.0-beta-pre.cf265.1.gd50775b4.linux-amd64.zip
SCF_ARCHIVE=$(basename $SCF_URL)
wget $SCF_URL
unzip $SCF_ARCHIVE

# Fetch predetermined version of the ui
CONSOLE_URL=https://github.com/SUSE/stratos-ui/releases/download/0.9.5/console-helm-chart-0.9.5.tgz
CONSOLE_ARCHIVE=$(basename $CONSOLE_URL)
wget $CONSOLE_URL
tar xzf $CONSOLE_ARCHIVE
