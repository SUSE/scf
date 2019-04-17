#!/usr/bin/env bash

# Restore the Fissile cache.

set -o errexit -o nounset

echo 'if test -e /mnt/hgfs ; then /mnt/hgfs/scf/bin/dev/setup_vmware_mounts.sh ; fi' >> .profile

echo 'export PATH="${PATH}:${HOME}/scf/container-host-files/opt/scf/bin/"' >> .profile

echo -e '\nexport HISTFILE="${HOME}/scf/output/.bash_history"' >> .profile

# Check that the cluster is reasonable.
${HOME}/scf/bin/dev/kube-ready-state-check.sh

direnv exec ${HOME}/scf make -C ${HOME}/scf copy-compile-cache
