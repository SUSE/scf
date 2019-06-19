#!/usr/bin/env bash

# Set up direnv so we can pick up fissile configuration.

set -o errexit -o nounset

mkdir -p ${HOME}/bin
wget -O ${HOME}/bin/direnv --no-verbose \
  https://github.com/direnv/direnv/releases/download/v2.11.3/direnv.linux-amd64
chmod a+x ${HOME}/bin/direnv
echo 'eval "$(${HOME}/bin/direnv hook bash)"' >> ${HOME}/.bashrc
ln -s -f ${HOME}/scf/bin/dev/vagrant-envrc ${HOME}/.envrc
${HOME}/bin/direnv allow ${HOME}
${HOME}/bin/direnv allow ${HOME}/scf
