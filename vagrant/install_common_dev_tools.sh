#!/usr/bin/env bash

# Install common and dev tools.

set -o errexit -o xtrace -o verbose

export HOME=$1
export VM_REGISTRY_MIRROR=$2

export PATH="${PATH}:${HOME}/bin"
export SCF_BIN_DIR=/usr/local/bin

if [ -n "${VM_REGISTRY_MIRROR}" ]; then
  perl -p -i -e "s@^(DOCKER_OPTS=)\"(.*)\"@\\1\"\\2 --registry-mirror=${VM_REGISTRY_MIRROR}\"@" /etc/sysconfig/docker
  # Docker has issues coming up on virtualbox; let it fail gracefully, if necessary.
  systemctl stop docker.service
  if ! systemctl restart docker.service ; then
    while [ "$(systemctl is-active docker.service)" != active ] ; do
      case "$(systemctl is-active docker.service)" in
        failed) systemctl reset-failed docker.service ;
                systemctl restart docker.service ||: ;;
        *)      sleep 5                              ;;
      esac
    done
  fi
fi

cd "${HOME}/scf"
bash ${HOME}/scf/bin/common/install_tools.sh
direnv exec ${HOME}/scf/bin/dev/install_tools.sh

# Enable RBAC for kube on vagrant boxes older than 2.0.10.
if ! grep -q "KUBE_API_ARGS=.*--authorization-mode=RBAC" /etc/kubernetes/apiserver; then
  perl -p -i -e 's@^(KUBE_API_ARGS=)"(.*)"@\\1"\\2 --authorization-mode=RBAC"@' /etc/kubernetes/apiserver
  systemctl restart kube-apiserver
fi
