#!/bin/bash
set -o errexit -o nounset

# Get version information and set destination dirs
. "$(dirname "$0")/versions.sh"

# Installs tools needed to build and run HCF
SCF_BIN_DIR="${SCF_BIN_DIR:-/home/vagrant/bin}"
SCF_TOOLS_DIR="${SCF_TOOLS_DIR:-/home/vagrant/tools}"
cf_url="${cf_url:-https://cli.run.pivotal.io/stable?release=linux64-binary&version=${CFCLI_VERSION}&source=github-rel}"
kubectl_url="${kubectl_url:-https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl}"
k_url="${k_url:-https://github.com/aarondl/kctl/releases/download/v${K_VERSION}/kctl-linux-amd64}"
kk_url="${kk_url:-https://gist.githubusercontent.com/jandubois/${KK_VERSION}/raw/}"
helm_url="${helm_url:-https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz}"

mkdir -p "${SCF_BIN_DIR}"
mkdir -p "${SCF_TOOLS_DIR}"

SCF_BIN_DIR="$(cd "${SCF_BIN_DIR}" && pwd)"

echo "Fetching cf CLI $cf_url ..."
wget -q "$cf_url"        -O "${SCF_TOOLS_DIR}/cf.tgz"

# Certstrap is used for creating the k8s signing keys, which are necessary to avoid communication bugs on host restarts
echo "Installing certstrap ..."
# We run chown in docker to avoid requiring sudo
docker run --rm -v "${SCF_BIN_DIR}":/out:rw "golang:${GOLANG_VERSION}" /usr/bin/env GOBIN=/out go get github.com/square/certstrap
docker run --rm -v "${SCF_BIN_DIR}":/out:rw "golang:${GOLANG_VERSION}" /bin/chown "$(id -u):$(id -g)" /out/certstrap

echo "Unpacking cf CLI ..."
tar -xzf "${SCF_TOOLS_DIR}/cf.tgz" -C "${SCF_BIN_DIR}"

wget -q "${k_url}" -O "${SCF_BIN_DIR}/k"
wget -q "${kk_url}" -O "${SCF_BIN_DIR}/kk"

echo "Fetching helm from ${helm_url} ..."
wget -q "${helm_url}" -O - | tar xz -C "${SCF_BIN_DIR}" --strip-components=1 linux-amd64/helm

echo "Making binaries executable ..."
chmod a+x "${SCF_BIN_DIR}/cf"
chmod a+x "${SCF_BIN_DIR}/k"
chmod a+x "${SCF_BIN_DIR}/kk"
chmod a+x "${SCF_BIN_DIR}/helm"

# Note that we might not have a k8s available; do this only if we're in vagrant
if systemctl is-active kube-apiserver.service ; then
  echo "Installing tiller for helm ..."
  helm init
else
  echo "Skipping tiller installation for helm; no local kube found"
fi

echo "Common tool installation done."
