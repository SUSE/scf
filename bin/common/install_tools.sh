#!/usr/bin/env bash
set -o errexit -o nounset
set -vx

# Get version information and set destination dirs
. "$(dirname "$0")/versions.sh"

# Installs tools needed to build and run SCF
SCF_BIN_DIR="${SCF_BIN_DIR:-output/bin}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=${CFCLI_VERSION}&source=github-rel}"
kubectl_url="${kubectl_url:-https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl}"
k_url="${k_url:-https://github.com/aarondl/kctl/releases/download/v${K_VERSION}/kctl-linux-amd64}"
kk_url="${kk_url:-https://gist.githubusercontent.com/jandubois/40a5b3756cf4bcbed940e6156272c0af/raw/${KK_VERSION}/kk}"
helm_url="${helm_url:-https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz}"

mkdir -p "${SCF_BIN_DIR}"

SCF_BIN_DIR="$(unset CDPATH ; cd "${SCF_BIN_DIR}" && pwd)"

echo "Fetching cf CLI $cf_url ..."
wget -q "$cf_url" -O "/tmp/cf.tgz"

echo "Unpacking cf CLI ..."
tar -xzf "/tmp/cf.tgz" -C "${SCF_BIN_DIR}"

if ! type kubectl &>/dev/null; then
  echo "Fetching kubectl ${kubectl_url} ..."
  wget -q "${kubectl_url}" -O "${SCF_BIN_DIR}/kubectl"
  chmod a+x "${SCF_BIN_DIR}/kubectl"
fi
wget -q "${k_url}" -O "${SCF_BIN_DIR}/k"
wget -q "${kk_url}" -O "${SCF_BIN_DIR}/kk"

echo "Fetching helm from ${helm_url} ..."
wget -q "${helm_url}" -O - | tar xz -C "${SCF_BIN_DIR}" --no-same-owner --strip-components=1 linux-amd64/helm

echo "Making binaries executable ..."
chmod a+x "${SCF_BIN_DIR}/cf"
chmod a+x "${SCF_BIN_DIR}/k"
chmod a+x "${SCF_BIN_DIR}/kk"
chmod a+x "${SCF_BIN_DIR}/helm"

# The vagrant deployment runs this script privileged, so init helm as vagrant user if they exist.
if systemctl list-unit-files kube-apiserver.service | grep --quiet enabled ; then
  if [[ $(id -u) -eq 0 ]] && id -u vagrant &>/dev/null; then
    do_as_vagrant="sudo -iu vagrant"
  else
    do_as_vagrant=""
  fi

  # Wait for kube-apiserver to actually be ready
  while ! systemctl is-active kube-apiserver.service ; do
    sleep 1
  done

  echo "Installing tiller for helm ..."
  ${do_as_vagrant} helm init
else
  echo "Skipping tiller installation for helm; no local kube found"
fi

echo "Common tool installation done."
